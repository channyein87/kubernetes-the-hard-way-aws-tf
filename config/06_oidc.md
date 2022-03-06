# Pod OIDC IAM Authentication

```bash
sh config/06_oidc.sh

kubectl exec awscli -- env  | grep AWS

kubectl exec awscli -- aws sts get-caller-identity
```
