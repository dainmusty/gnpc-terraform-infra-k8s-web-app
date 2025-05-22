#!/bin/bash

set -e

CLUSTER_NAME="effulgencetech-dev"
REGION="us-east-1"
NODEGROUP_NAME="et-nodegroup"
NODE_TYPE="t2.medium"
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 1. Create EKS cluster
eksctl create cluster --name $CLUSTER_NAME --region $REGION --nodegroup-name $NODEGROUP_NAME --node-type $NODE_TYPE --nodes 2 --nodes-min 1 --nodes-max 3 --managed

# 2. Wait for cluster to be ACTIVE
echo "Waiting for EKS cluster to become ACTIVE..."
while true; do
  STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.status" --output text)
  if [ "$STATUS" == "ACTIVE" ]; then
    echo "Cluster is ACTIVE."
    break
  else
    echo "Current status: $STATUS. Waiting 30 seconds..."
    sleep 30
  fi
done

# 3. Associate IAM OIDC provider
eksctl utils associate-iam-oidc-provider --region $REGION --cluster $CLUSTER_NAME --approve

# 4. Download IAM policy for AWS Load Balancer Controller
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.1/docs/install/iam_policy.json

# 5. Create IAM policy
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"
if aws iam get-policy --policy-arn $POLICY_ARN &> /dev/null; then
  echo "IAM policy $POLICY_NAME already exists. Skipping creation."
else
  echo "Creating IAM policy $POLICY_NAME..."
  aws iam create-policy --policy-name $POLICY_NAME --policy-document file://iam_policy.json
fi


# 6. Create IAM service account and attach policy
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn $POLICY_ARN \
  --approve \
  --override-existing-serviceaccounts


# 7. Add and update Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# 8. Update kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# 9. Get VPC ID dynamically
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)
echo "Using VPC ID: $VPC_ID"

# 10. Install AWS Load Balancer Controller via Helm
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$VPC_ID

# 11. Check deployment
kubectl get deployment -n kube-system aws-load-balancer-controller

# Wait for AWS Load Balancer Controller pods to be ready
echo "Waiting for AWS Load Balancer Controller to be ready..."
kubectl rollout status deployment aws-load-balancer-controller -n kube-system --timeout=120s


# 12. Deploy application resources
kubectl create namespace phone-store || true
kubectl apply -f web-deployment.yml
kubectl apply -f web-service.yml
kubectl apply -f ingress.yml

kubectl get pods -n phone-store
kubectl get ingress -n phone-store

# 13. Echo the ALB address from the ingress
ALB_HOSTNAME=$(kubectl get ingress -n phone-store -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "Your ALB is available at: http://$ALB_HOSTNAME"
