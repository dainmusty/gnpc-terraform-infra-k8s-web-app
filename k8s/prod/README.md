



docker build -t dainmusty/fonapp:tag .



























docker run -d \
  --name web-app \
  -p 3000:3000 \
  --env MONGODB_URI=mongodb://host.docker.internal:27017/webapp \
  nanajanashia/k8s-demo-app:v1.0



docker run -d \
  --name web-app \
  -p 3000:3000 \
  --env MONGODB_URI=mongodb://34.238.155.83:27017/webapp \
  nanajanashia/k8s-demo-app:v1.0


host.docker.internal tells the web app to connect to the host system (your EC2 machine), which is running MongoDB.

If that doesn't work (older Docker versions on Linux may not support it), use this alternative:

🔁 Alternative (Linux): Use the EC2 Private IP
Get the EC2 instance's private IP:

bash
Copy
Edit
hostname -I
Let's say it returns 10.0.1.164.

Run the container with:

bash
Copy
Edit
docker run -d \
  --name web-app \
  -p 3000:3000 \
  --env MONGODB_URI=mongodb://10.0.1.164:27017/webapp \
  nanajanashia/k8s-demo-app:v1.0
✅ Step 3: Check It’s Running
bash
Copy
Edit
docker ps
You should see both containers up:

python-repl
Copy
Edit
CONTAINER ID   IMAGE                             PORTS                    NAMES
...            nanajanashia/k8s-demo-app:v1.0    0.0.0.0:3000->3000/tcp   web-app
...            mongo                             0.0.0.0:27017->27017/tcp mongo
🌐 Step 4: Access in Browser
Go to:

cpp
Copy
Edit
http://<your-EC2-public-ip>:3000
Make sure your security group allows inbound access on port 3000.

Let me know if you'd like to run both with docker-compose next — it makes this setup much cleaner!









Ask ChatGPT



Tools


