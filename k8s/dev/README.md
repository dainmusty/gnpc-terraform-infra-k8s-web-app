terraform-infra/
├── k8s-resources/
│   ├── dev/
│   │   ├── namespace.yaml  # kubectl create namespace phone-store

│   │   ├── postgres/
│   │   │   ├── pvc.yaml
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   ├── app/
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   ├── web/
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   └── ingress.yaml
│   ├── staging/
│   └── prod/

# you can either launch your eks with terraform kubernetes provider or use eksctl

# to create a cluster
 eksctl create cluster --name effulgencetech-dev --region us-east-1 --nodegroup-name et-nodegroup --node-type t2.medium --nodes 2 --nodes-min 1 --nodes-max 3 --managed 

# to delete a cluster
 eksctl delete cluster --name effulgencetech-dev --region us-east-1


1. Should the Ingress Controller be deployed first?
Yes. Best practice is to:

First deploy the Ingress Controller (like AWS ALB Ingress Controller or NGINX Ingress Controller) — this sets up the ingress class needed by the ingress resources.

Then deploy your application (pods, services).

Finally, deploy your Ingress object that ties domain routing to your services.

This sequence ensures:

The ingress resource doesn’t enter a failed state due to missing controller.

The controller is ready to watch and configure routing as soon as your ingress object is created.


Overview of Steps
Install ALB Ingress Controller (a.k.a. AWS Load Balancer Controller)

Create Ingress resources in your namespace

Ensure your domain or access is routed through the ALB

(Optional but recommended) Use ACM for HTTPS (SSL/TLS)

🔧 Step 1: Install AWS Load Balancer Controller
🛠️ Prerequisites
IAM OIDC provider is enabled for your EKS cluster.

You have eksctl, kubectl, and helm installed.

Your kubectl is authenticated to your EKS cluster.

# to create a cluster
 ✅ 1.0 eksctl create cluster --name effulgencetech-dev --region us-east-1 --nodegroup-name et-nodegroup --node-type t2.medium --nodes 2 --nodes-min 1 --nodes-max 3 --managed 

# to create node group if you want to increase the no. nodes
eksctl create nodegroup \
  --cluster effulgencetech-dev \
  --name standard-workers-t3 \
  --node-type t2.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --region us-east-1 \
  --managed
✅ 1.1 Enable OIDC provider (if not already done)
eksctl utils associate-iam-oidc-provider --region <your-region> --cluster <your-cluster-name> --approve
# for example
eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster effulgencetech-dev --approve

✅ 1.2 Create IAM policy for the ALB controller
Download and create the IAM policy:

✅ 1.3  curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.1/docs/install/iam_policy.json


✅ 1.4 aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json


✅ 1.5 Create a service account and attach IAM policy

eksctl create iamserviceaccount --cluster effulgencetech-dev --namespace kube-system --name aws-load-balancer-controller --attach-policy-arn arn:aws:iam::651706774390:policy/AWSLoadBalancerControllerIAMPolicy --approve


✅ 1.6 Install the AWS Load Balancer Controller with Helm

✅ 1.7 helm repo add eks https://aws.github.io/eks-charts
✅ 1.8 helm repo update
✅ 1.9 aws eks update-kubeconfig --region us-east-1 --name effulgencetech-dev

# Use helm to install the alb controller
✅ 2.1 helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --set clusterName=effulgencetech-dev --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller --set region=us-east-1 --set vpcId=vpc-09cdcb2a6fe528c8e

You can verify it’s running with:

✅ 2.0 kubectl get deployment -n kube-system aws-load-balancer-controller

# Apply in Order (important)
You need to make sure the namespace exists:

kubectl create namespace phone-store

Then deploy in this order:

kubectl apply -f web-deployment.yml
kubectl apply -f web-service.yml
kubectl apply -f ingress.yml

or create all together once but in order
kubectl apply -f k8s-resources/dev/

Now confirm the pods are running:

kubectl get pods -n phone-store

# And get the external ALB URL:
 
kubectl get ingress -n phone-store


Then access the app via:
http://<ec2-node-public-ip>:30080

terraform-infra/
├── k8s-resources/
│   ├── dev/
│   │   └── ...
│
├── docker-images/
│   ├── phone-store/
│   │   ├── Dockerfile
│   │   ├── index.html
│   │   ├── styles.css
│   │   └── app.js
│   └── other-app/
│       └── ...
# to build images locally
1. docker build -t phone-store .
2. docker tag phone-store dainmusty/phone-store:latest
3. docker login
4. docker build -t phone-store .
5. docker push dainmusty/phone-store:latest

# to create the container from the image
3. docker run -d -p 8081:80 --restart always phone-store
4. docker ps # to check which containers are running
5. 
the phone store web app worked. but i stopped the instance and restarted it, tried the browser with the new ip but it says site can't be reached. do i need to restart the container or something or the nginx web server?


ChatGPT said:
Yes, exactly — when you stop and restart an EC2 instance, two important things happen:

🔁 1. Public IP Changes
The EC2 instance gets a new public IP unless it's associated with an Elastic IP.

So your old IP won’t work anymore.

✅ Solution:
Use the new public IP in your browser. Or better:
👉 Assign an Elastic IP to make it static.

🔄 2. Docker Container Stops on Reboot
By default, Docker containers do not restart automatically after an EC2 reboot.

✅ Solution Options:

Option A: Manually restart the container
SSH into the EC2 instance and run:

bash
Copy
Edit
docker ps -a        # See if the container exists but is exited
docker start <container_id_or_name>
Option B: Use --restart flag when running the container
This makes Docker auto-restart the container on system reboot:

bash
Copy
Edit
docker run -d -p 80:80 --restart always phone-store
You’ll need to re-run it this way once, and next time EC2 restarts, Docker will bring it up automatically.

✅ Bonus: Check if NGINX or any errors are the issue
If you’re using NGINX as a reverse proxy (not just your Node app), you might also need to:

bash
Copy
Edit
sudo systemctl restart nginx
But in your case (running directly with docker run -p 80:80), NGINX inside the container should handle it.

Would you like help setting up the container to always run on reboot using a service or Docker Compose?






You said:
do i need to change the external port number when running the command below?
docker run -d -p 8081:80 phone-store. should i now make it docker run -d -p 8082:80 --restart always phone-store ?


ChatGPT said:
You do not need to change the external port (from 8081 to 8082) unless you specifically want to serve your app on a different port.

Here’s what the -p flag does:

ruby
Copy
Edit
-p <host_port>:<container_port>
host_port = the port on the EC2 instance (what you type in the browser)

container_port = the port inside the container (your app usually runs on port 80)

✅ If you're already using port 8081, just add --restart always:
bash
Copy
Edit
docker run -d -p 8081:80 --restart always phone-store
This way:

The app remains on http://<EC2-IP>:8081

It will automatically start after a reboot

✅ When should you change the port?
Only if:

You want to run multiple containers on the same EC2

Or port 8081 is already taken

Or you want to switch to a standard HTTP port like 80

docker run -d -p 8081:80 --restart always phone-store


# before pushing your image to dockerhub or ECR or GCR, you have to log into the hub or the registry


it worked. thanks. now that the app is running fine. now the next step is to incorporate the container into the manifest files. so lets do that please together


ChatGPT said:
Great — glad it’s working!

Now let’s incorporate your containerized phone store app into Kubernetes using manifest files.

🎯 Objective
You want to deploy your app (which is containerized) using Kubernetes manifests (YAML files). That usually involves:

Deployment – To run your container with replicas.

Service – To expose the app within the cluster (and possibly outside).

(Optional) Ingress – To expose it externally with a custom domain.

(Optional) ConfigMap/Secrets – If your app needs environment config or secrets.

✅ Step-by-Step: Minimal Working Setup
Let’s assume your image is named phone-store and built locally. If you're pushing it to Docker Hub or ECR, let me know.

1. deployment.yaml
yaml
Copy
Edit
apiVersion: apps/v1
kind: Deployment
metadata:
  name: phone-store-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: phone-store
  template:
    metadata:
      labels:
        app: phone-store
    spec:
      containers:
      - name: phone-store
        image: phone-store:latest  # replace with your registry path if needed
        ports:
        - containerPort: 80
2. service.yaml
yaml
Copy
Edit
apiVersion: v1
kind: Service
metadata:
  name: phone-store-service
spec:
  selector:
    app: phone-store
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: NodePort  # Change to LoadBalancer if using a cloud provider
🔄 Apply the Manifests
If you’re running locally with minikube or kind, use:

bash
Copy
Edit
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
Then get the service details:

bash
Copy
Edit
kubectl get svc phone-store-service
If NodePort, access it using:

bash
Copy
Edit
minikube service phone-store-service
🔄 If You're Pushing to Docker Hub
You’ll need to:

Tag the image:

bash
Copy
Edit
docker tag phone-store <your-dockerhub-username>/phone-store
Push it:

bash
Copy
Edit
docker push <your-dockerhub-username>/phone-store
Update the manifest image: line to:

yaml
Copy
Edit
image: <your-dockerhub-username>/phone-store:latest
Would you like to:

Push this image to Docker Hub or ECR?

Add Ingress with a custom domain or TLS?

Include ConfigMaps or Secrets?

Let me know what next step you'd like to include.






You said:
so i have a question. lets say i successfully deploy my eks with terraform. now that my manifest files are in vscode locally. how do i complete the section of the deployment file below

 containers:
      - name: phone-store
        image: phone-store:latest  # replace with your registry path if needed
        ports:
        - containerPort: 80

do i put the phone store image name  at image:? and how does my eks cluster identify or source the phone store image? does it mean all container images have to be published to dockerhub or ecr? and are there other hubs in the industry or it's just these 2?


ChatGPT said:
Great set of questions — you’re thinking exactly like a cloud-native DevOps pro. Let’s break it down clearly:

✅ How to Complete This Section
yaml
Copy
Edit
containers:
  - name: phone-store
    image: phone-store:latest  # You need a fully qualified image URL here
    ports:
      - containerPort: 80
You cannot use phone-store:latest directly unless:

The image is already built on each EKS node manually (not practical or scalable).

You're using a local dev cluster (like minikube) with local Docker context.

So, in EKS (Amazon's Kubernetes), you must push your image to a registry your cluster nodes can access.

🔁 Real-World Practice
You must publish your image somewhere accessible:
Two major public/private registries:

Amazon ECR (Elastic Container Registry) – Best choice if you’re on AWS.

Docker Hub – Public or private image repository.

Other popular registries include:
GitHub Container Registry (GHCR)

Google Container Registry / Artifact Registry

Azure Container Registry (ACR)

Harbor – An open-source on-prem/private registry

✅ What to Do in Practice
A. Tag and Push Your Image to Docker Hub (or ECR)
Docker Hub (simpler for individuals):
bash
Copy
Edit
docker tag phone-store mustydev/phone-store:latest
docker push mustydev/phone-store:latest
Then in your manifest:

yaml
Copy
Edit
image: mustydev/phone-store:latest
ECR (AWS-native, more secure/enterprise):
Authenticate:

bash
Copy
Edit
aws ecr get-login-password | docker login --username AWS --password-stdin <your-aws-account-id>.dkr.ecr.<region>.amazonaws.com
Tag:

bash
Copy
Edit
docker tag phone-store <aws-ecr-repo-url>:latest
Push:

bash
Copy
Edit
docker push <aws-ecr-repo-url>:latest
Then update your manifest:

yaml
Copy
Edit
image: <aws-ecr-repo-url>:latest
B. IAM Permissions on EKS
If you use Amazon ECR, EKS automatically authenticates to pull images if the nodes have the right IAM permissions (standard setup from Terraform modules usually includes this).

🔒 Summary
Registry	Private Support	Best For	Notes
ECR	✅ Yes	AWS-hosted workloads	Secure, IAM-integrated
Docker Hub	✅ Yes (limited)	Public/demo projects	Free limits, simple for testing
GitHub GHCR	✅ Yes	Devs using GitHub	Integrated with Actions
Azure ACR / GCP GCR	✅ Yes	Cloud-specific	Good in Azure/GCP setups
Harbor	✅ Yes	Self-hosted	Requires more management effort

Would you like me to walk you through:

Tagging and pushing to ECR, or

Using Docker Hub for now?






You said:
 but if i push the image to dockerhub, can eks access it through the deployment files?


ChatGPT said:
Yes, EKS can absolutely access Docker Hub images directly through your deployment files — as long as the image is public on Docker Hub, or the cluster has credentials for private access.

✅ If the Docker Hub Image Is Public
You just reference it directly in your manifest:

yaml
Copy
Edit
containers:
  - name: phone-store
    image: your-dockerhub-username/phone-store:latest
    ports:
      - containerPort: 80
And that’s it. No authentication is needed — EKS nodes will pull the image from Docker Hub automatically.

🔒 If the Docker Hub Image Is Private
Then you’ll need to give EKS access via an image pull secret.

Step 1: Create a Kubernetes secret
bash
Copy
Edit
kubectl create secret docker-registry regcred \
  --docker-username=your-dockerhub-username \
  --docker-password=your-dockerhub-password \
  --docker-email=your-email@example.com \
  --namespace=default
Step 2: Reference that secret in your deployment YAML:
yaml
Copy
Edit
spec:
  containers:
    - name: phone-store
      image: your-dockerhub-username/phone-store:latest
      ports:
        - containerPort: 80
  imagePullSecrets:
    - name: regcred
🚀 Best Practice
For public apps or learning purposes, Docker Hub (public) is fine.

But for production, especially on AWS:

Use Amazon ECR for better performance, security, IAM integration, and private image hosting with minimal friction.

Would you like to use Docker Hub public images for now and write a sample manifest with me based on that?






You said:
yes please lets use docker hub


ChatGPT said:
Great! Let's walk through using Docker Hub with your EKS deployment step by step.

✅ Step 1: Tag and Push Your Image to Docker Hub
Assuming your image is built locally as phone-store:latest:

bash
Copy
Edit
# Tag your local image for Docker Hub
docker tag phone-store:latest your-dockerhub-username/phone-store:latest

# Log in to Docker Hub
docker login

# Push to Docker Hub
docker push your-dockerhub-username/phone-store:latest
✅ Step 2: Update Your Kubernetes Deployment Manifest
Here’s a simple deployment.yaml assuming you pushed a public image:

yaml
Copy
Edit
apiVersion: apps/v1
kind: Deployment
metadata:
  name: phone-store-deployment
  labels:
    app: phone-store
spec:
  replicas: 2
  selector:
    matchLabels:
      app: phone-store
  template:
    metadata:
      labels:
        app: phone-store
    spec:
      containers:
        - name: phone-store
          image: your-dockerhub-username/phone-store:latest
          ports:
            - containerPort: 80
✅ Replace your-dockerhub-username with your actual Docker Hub username.

✅ Step 3: Deploy to EKS
Make sure you're authenticated to your EKS cluster (via aws eks update-kubeconfig), then:

bash
Copy
Edit
kubectl apply -f deployment.yaml
You can also create a service.yaml to expose it, either as a LoadBalancer or NodePort.

kubectl create namespace phone-store
