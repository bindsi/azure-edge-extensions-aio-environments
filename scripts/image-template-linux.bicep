param location string = resourceGroup().location
param identityId string
param stagingResourceGroupName string
//param imageVersionNumber string
param runOutputName string = 'arc_footprint_image'
param imageTemplateName string

param galleryImageId string

param publisher string
param offer string
param sku string
param version string
param vmSize string

output id string = azureImageBuilderTemplate.id

resource azureImageBuilderTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2022-02-14' = {
  name: imageTemplateName
  location: location
  tags: {}
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    buildTimeoutInMinutes: 180
    customize: [
      {
        type: 'Shell'
        name: 'Install K3s'
        inline: [
          'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.5+k3s1 sh -'
          'mkdir -p ~/.kube'
          'sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl config view'
        ]
      }
      {
        type: 'Shell'
        name: 'Install nfs-common'
        inline: [
          'sudo apt-get update'
          'sudo apt-get install -y nfs-common'
        ]
      }
      {
        type: 'Shell'
        name: 'Increase the user watch/instance and file descriptor limits'
        inline: [
          'echo fs.inotify.max_user_instances=8192 | sudo tee -a /etc/sysctl.conf'
          'echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf'
          'echo fs.file-max = 100000 | sudo tee -a /etc/sysctl.conf'
          'sudo sysctl -p'
        ]
      }
      {
        type: 'Shell'
        name: 'Install Azure CLI and jq'
        inline: [
          'curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash'
          'sudo apt-get install -y jq'
        ]
      }
      {
        type: 'Shell'
        name: 'Install Kubectl'
        inline: [
          'sudo apt-get update'
          'sudo apt-get install -y ca-certificates curl'
          'sudo mkdir -p "/etc/apt/keyrings"'
          'curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg'
          'sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg'
          'echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list'
          'sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list'
          'sudo apt-get update'
          'sudo apt-get install -y kubectl'
        ]
      }
      {
        type: 'Shell'
        name: 'New dir'
        inline: [
          'sudo mkdir -p $HOME/hostmem'
        ]
      }
      {
        type: 'File'
        name: 'cgroup_mem.sh'
        sourceUri: 'https://raw.githubusercontent.com/Azure-Samples/azure-edge-extensions-aio-environments/main/scripts/images/cgroup_mem.sh'
        destination: '/tmp/cgroup_mem.sh'
      }
      {
        type: 'Shell'
        name: 'Create hostmem collection job'
        inline: [
          'sudo chmod +x /tmp/cgroup_mem.sh'
          'sudo mv /tmp/cgroup_mem.sh $HOME/hostmem'
          'echo "*/5 * * * * root $HOME/hostmem/cgroup_mem.sh" >> /etc/crontab'
        ]
      }
    ]
    distribute: [
      {
        type: 'SharedImage'
        runOutputName: runOutputName
        galleryImageId: galleryImageId
        replicationRegions: [
          location
        ]
        storageAccountType: 'Standard_LRS'
      }
    ]
    stagingResourceGroup: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${stagingResourceGroupName}'
    source: {
      type: 'PlatformImage'
      publisher: publisher
      offer: offer
      sku: sku
      version: version
    }
    validate: {}
    vmProfile: {
      vmSize: vmSize
      osDiskSizeGB: 0
    }
  }
}
