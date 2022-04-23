# AWS Load Balancer Controller add-on

```bash
sh config/07_alb.sh

kubectl logs -n kube-system $(kubectl get po -n kube-system | egrep -o 'aws-load-balancer-controller[a-zA-Z0-9-]+') | grep 'echoserver\/echoserver'

curl echoserver.josh-test-dns.com
```
