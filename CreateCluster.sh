
export VAGRANT_EXPERIMENTAL="disks"

vagrant up --provider=libvirt --no-parallel

sleep 60s

vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes"

echo Lets wait for all the nodes to become available. Sleeping for 60 seconds...

sleep 60s


vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /tmp/nodelocaldns.yaml"

#Deploy Portworx Enterprise
#vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /tmp/portworx-enterprise.yaml"

#Deploy Portworx Essentials
#vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /tmp/portworx-essentials.yaml"

vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /tmp/metrics.yaml"

vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f 'https://install.portworx.com/2.10?comp=prometheus-operator&kbver=1.23.5'"

vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf label nodes worker0.calvarado04.com worker1.calvarado04.com worker2.calvarado04.com px/metadata-node=true"

#Adding Nginx Ingress Controller
vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.2.0/deploy/static/provider/baremetal/deploy.yaml"

echo Restarting nodes due to pending CSR to be generated by the nodes...
#
vagrant ssh master.calvarado04.com  -c "sudo shutdown -r now"
vagrant ssh worker0.calvarado04.com -c "sudo shutdown -r now"
vagrant ssh worker1.calvarado04.com -c "sudo shutdown -r now"
vagrant ssh worker2.calvarado04.com -c "sudo shutdown -r now"
vagrant ssh worker3.calvarado04.com -c "sudo shutdown -r now"

#echo Lets wait for all the nodes to become available. Sleeping for two minutes...

sleep 80s

echo Continue...


vagrant ssh master.calvarado04.com -c "for certificate in $(sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get csr -o json | jq -r '.items[].metadata.name'); do sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf certificate approve $certificate; done"

echo Approve all the pending certificates
for certificate in $(vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get csr --no-headers" | grep -i pending |  awk '{ print $1 }'); 
  do vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf certificate approve ${certificate}"; 
done


vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes"

sleep 60s

vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -o wide -n kube-system -l name=portworx"

echo Approve all the pending certificates, second round
for certificate in $(vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get csr --no-headers" | grep -i pending |  awk '{ print $1 }'); 
  do vagrant ssh master.calvarado04.com -c "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf certificate approve ${certificate}"; 
done


#Day 2 tasks to perform:

#vagrant ssh master.calvarado04.com -c "sudo cat /etc/kubernetes/admin.conf" > ${HOME}/.kube/config

#Add external workers as Ingress Endpoints
#kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec":{"externalIPs":["192.168.121.200","192.168.121.201","192.168.121.202"]}}'


#kubectl -n kube-system create secret generic px-vol-encryption --from-literal=cluster-wide-secret-key=key-to-encrypt-my-volumes-on-portworx

#PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')

#kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl secrets set-cluster-key --secret cluster-wide-secret-key
