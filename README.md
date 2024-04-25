En este ejemplo partiremos del Cluster MPI montado previamente en Kubernetes.
El objetivo de de esta práctica es mejorar dicho clúster usando Helm.

# Primeros cambios
## Nombres objetos

En primer lugar es una mala práctica *hardcodear* el nombre de un objeto de kubernetes. Los nombres deberían ser únicos a un release([Fuente](https://helm.sh/docs/chart_template_guide/getting_started/#adding-a-simple-template-call)) Por lo tanto usaremos la forma `{{ .Release.Name }}-[nombre]` para nombrar a cada objeto.

Por ejemplo:
```yaml title:pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ .Release.Name }}-mpife
...
```

De este manera, el *frontend* ahora será nombrado en función del nombre del *release* escogido.

## Etiquetas 
En los manifiestos usamos una etiqueta para relacionar `Deployments` y `Services`. En el caso de que en un futuro quisiéramos modificar la aplicación, habría una posibilidad de que el desarrollador cometiera el error de cambiar el nombre de esta etiqueta en un lado pero no en el otro, haciendo que todo deje de funcionar.
Es por eso que solventaremos este posible error humano añadiendo dicha etiqueta como un `Value`.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-worker
spec:
  selector:
    matchLabels:
      app: {{ .Values.appName }}
  replicas: 2
  template:
    metadata:
      labels:
        app: {{ .Values.appName }}
        type: worker
    spec:
      containers:
      - name: mpiwn
        image: agalrui/mi-sshd:latest
        command: [ "/usr/sbin/sshd", "-D"  ]

        volumeMounts:
          - name: nfs
            subPath: mpi
            mountPath: "/nfs"
      volumes:
        - name: nfs
          persistentVolumeClaim:
            claimName: nfs-pvc

---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-workers-service
spec:
  ports:
  - port: 22
    targetPort: 22
  selector:
    app: {{ .Values.appName }}
    type: worker
```

## Escalado
Nuestro clúster cuenta con un `Deployment` donde hemos fijado el número de réplicas a 2. Podríamos añadir este valor como un `Value` de Helm para que el usuario escalara el sistema mucho más fácilmente

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-worker
spec:
  selector:
    matchLabels:
      app: {{ .Values.appName }}
  replicas: {{ .Values.replicaCount }}
```

## Imagen
Podemos también establecer como valores de Helm la imagen y etiqueta a usar por los `Pods`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ .Release.Name }}-mpife
  labels:
    app: {{ .Values.appName }}
    type: frontend
spec:
  containers:
  - name: mpife
    image: {{ .Values.image.name}}:{{ .Values.image.tag }}
    command: [ "/usr/sbin/sshd", "-D" ]
```

De esta manera podremos cambiar manual e individualmente tanto la imagen como la etiqueta de los contenedores.

## NFS
Podemos meter como valores de Helm la IP del servidor NFS así como su ruta, de manera que podamos cambiar más fácilmente de servidor de almacenamiento.

```yaml new:13-14,48
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
spec:
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: nfs-subdir
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: {{ .Values.nfs.server_ip }}
    path: {{ .Values.nfs.path }}
    readOnly: false

---

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: "nfs-subdir"
  resources:
    requests:
      storage: 100Mi

---

apiVersion: v1
kind: Pod
metadata:
  name: {{ .Release.Name }}-mpife
  labels:
    app: {{ .Values.appName }}
    type: frontend
spec:
  containers:
  - name: mpife
    image: {{ .Values.image.name}}:{{ .Values.image.tag }}
    command: [ "/usr/sbin/sshd", "-D" ]
  
    volumeMounts:
      - name: nfs
        subPath: {{ .Values.nfs.subpath}}
        mountPath: "/nfs"
  volumes:
    - name: nfs
      persistentVolumeClaim:
        claimName: nfs-pvc
```

Nota como hemos especificado también el *subpath*.

Seguramente este apartado pueda expandirse aún más, ofreciendo más personalización al sistema de almacenamiento.



# Pruebas
A continuación podemos probar el *chart* instalándolo.
```bash ln:false
alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ helm install mpi mi-mpi/
NAME: mpi
LAST DEPLOYED: Sun Apr  7 12:46:54 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

Si vemos los pods desplegados veremos que hay 3 instancias de *workers*.
```bash ln:false
alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ kgp
NAME                          READY   STATUS    RESTARTS   AGE
mpi-mpife                     1/1     Running   0          2m49s
mpi-worker-6c6bdcb5d5-msc77   1/1     Running   0          2m49s
mpi-worker-6c6bdcb5d5-t2ksd   1/1     Running   0          2m49s
mpi-worker-6c6bdcb5d5-t6dwl   1/1     Running   0          2m49s
```

Podemos cambiar el número de réplicas fácilmente.
```bash ln:false
alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ helm upgrade mpi mi-mpi/ --set replicaCount=5
Release "mpi" has been upgraded. Happy Helming!
NAME: mpi
LAST DEPLOYED: Sun Apr  7 12:51:55 2024
NAMESPACE: default
STATUS: deployed
REVISION: 2
TEST SUITE: None

alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ kgp
NAME                          READY   STATUS    RESTARTS   AGE
mpi-mpife                     1/1     Running   0          5m15s
mpi-worker-6c6bdcb5d5-j7xz4   1/1     Running   0          13s
mpi-worker-6c6bdcb5d5-msc77   1/1     Running   0          5m15s
mpi-worker-6c6bdcb5d5-t2ksd   1/1     Running   0          5m15s
mpi-worker-6c6bdcb5d5-t6dwl   1/1     Running   0          5m15s
mpi-worker-6c6bdcb5d5-wdl59   1/1     Running   0          13s
```

Por último, podemos ver que tras esta actualización estamos en la segunda revisión del *chart*.
```bash ln:false
alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ helm history mpi
REVISION        UPDATED                         STATUS          CHART           APP VERSION     DESCRIPTION     
1               Sun Apr  7 12:46:54 2024        superseded      mi-mpi-0.1.0    1.16.0          Install complete
2               Sun Apr  7 12:51:55 2024        deployed        mi-mpi-0.1.0    1.16.0          Upgrade complete
```

Una de las ventajas que nos ofrece Helm, es que podemos hacer rápidamente un *rollback* a una revisión anterior.
```bash ln:false
alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ helm rollback mpi 1
Rollback was a success! Happy Helming!
alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ helm history mpi
REVISION        UPDATED                         STATUS          CHART           APP VERSION     DESCRIPTION     
1               Sun Apr  7 12:46:54 2024        superseded      mi-mpi-0.1.0    1.16.0          Install complete
2               Sun Apr  7 12:51:55 2024        superseded      mi-mpi-0.1.0    1.16.0          Upgrade complete
3               Sun Apr  7 12:55:06 2024        deployed        mi-mpi-0.1.0    1.16.0          Rollback to 1   
alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ kgp
NAME                          READY   STATUS    RESTARTS   AGE
mpi-mpife                     1/1     Running   0          8m21s
mpi-worker-6c6bdcb5d5-msc77   1/1     Running   0          8m21s
mpi-worker-6c6bdcb5d5-t2ksd   1/1     Running   0          8m21s
mpi-worker-6c6bdcb5d5-t6dwl   1/1     Running   0          8m21s
```



# Creación de diferentes entornos

## Primera opción
Otro añadido al clúster es la posibilidad de crear dos archivos con valores distintos dependiendo de si se trata de un entorno de producción o de desarrollo.
Así, tras añadir el *namespace* como un *value* a cada objeto de kubernetes, podríamos tener lo siguiente:
```yaml title:values-dev.yaml
namespace: dev

replicaCount: 2
```

```yaml title:values-prod.yaml
namespace: prod

replicaCount: 10
```

De este modo, el número de réplicas cambiará en función del *namespace*.

```bash ln:false
alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ helm install mpi mi-mpi/ -f mi-mpi/values-dev.yaml -n dev
NAME: mpi
LAST DEPLOYED: Sun Apr  7 13:23:35 2024
NAMESPACE: dev
STATUS: deployed
REVISION: 1
TEST SUITE: None
alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ kubectl get pods --namespace dev
NAME                          READY   STATUS    RESTARTS   AGE
mpi-mpife                     1/1     Running   0          3m52s
mpi-worker-5fbfd4d946-pnwzd   1/1     Running   0          3m47s
mpi-worker-5fbfd4d946-rxdf6   1/1     Running   0          3m48s
```

```bash ln:false
alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ helm install mpi mi-mpi/ -f mi-mpi/values-prod.yaml -n prod
NAME: mpi
LAST DEPLOYED: Sun Apr  7 13:30:27 2024
NAMESPACE: prod
STATUS: deployed
REVISION: 1
TEST SUITE: None
alejandro@alejandro-laptop:~/Escritorio/pruebaHelm$ kubectl get pods --namespace prod
NAME                          READY   STATUS    RESTARTS   AGE
mpi-mpife                     1/1     Running   0          4m14s
mpi-worker-5fbfd4d946-5h6f2   1/1     Running   0          4m14s
mpi-worker-5fbfd4d946-hm7kk   1/1     Running   0          4m14s
mpi-worker-5fbfd4d946-j4zhq   1/1     Running   0          4m14s
mpi-worker-5fbfd4d946-jqj69   1/1     Running   0          4m14s
mpi-worker-5fbfd4d946-kkpss   1/1     Running   0          4m13s
mpi-worker-5fbfd4d946-l66pn   1/1     Running   0          4m14s
mpi-worker-5fbfd4d946-mknjs   1/1     Running   0          4m14s
mpi-worker-5fbfd4d946-ntzx8   1/1     Running   0          4m14s
mpi-worker-5fbfd4d946-qhlv5   1/1     Running   0          4m13s
mpi-worker-5fbfd4d946-xd6mb   1/1     Running   0          4m13s
```

## Segunda opción 
Otra opción en lugar de declarar el número de réplicas en cada archivo de valores de cada *namesapce* es crear una plantilla que establezca este número automáticamente en función del *namespace* escogido.

```
{{- define "mi-mpi.numberReplicas" -}}
    {{- if .Values.replicaCount -}}
        {{ .Values.replicaCount }}
    {{- else if eq .Values.namespace "dev" -}}
        2
    {{- else if eq .Values.namespace "prod" -}}
        10
    {{- else -}}
        4
    {{- end -}}
{{- end -}}
```
Este código buscará primero si existe un valor establecido en `replicaCount` y, en caso de que no lo haya, le asignará uno predeterminado.
De esta manera, dejaremos el valor de `replicaCount` como vacío para que se ponga por defecto el escogido, pero aún podemos escalar el sistema cambiando el valor de `replicaCount` al actualizar el *chart*.

Luego incluiríamos dicha plantilla en el *Deployment*.
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-worker
  namespace: {{ .Values.namespace}}
spec:
  selector:
    matchLabels:
      app: {{ .Values.appName }}
  replicas: {{ include "mi-mpi.numberReplicas" . }}
  ...
```

# Solventar automatización del *hostfile*
Para automatizar la creación del *hostfile*, podemos sustituir los Deployemnts por StatefulSet, ya que estos últimos mantienen siempre la misma forma de nombre. Luego, añadiriamos un Configmap que, usando Helm, automatizaría la creación del *hostfile* en función de las réplicas que se hayan especificado.
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
    hostfile: |
    {{- range $i := until (int (include "mi-mpi.numberReplicas" .)) }}
        mpi-worker-{{ $i }}.mpi-workers-service.default.svc.cluster.local
    {{- end }}
```