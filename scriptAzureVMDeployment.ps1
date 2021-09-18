# Installation des commandes Azure
Install-Module Az -AllowClobber -Force
# Connecter votre compte à Azure
Connect-AzAccount
# Modifier son context de travail (Changer d'abonnement)
Set-AzContext -Subscription "Alyf Formation"
$name="diallo"
$rg="rg-$name"
$location="FranceCentral"
$namesnetfe="snet-fe-$name"
$namesnetbe="snet-be-$name"
$namevnet="vnet-$name"
$prefixvnet="10.4.0.0/22"
$prefixsnetfe="10.4.0.0/24"
$prefixsnetbe="10.4.1.0/24"
$namensg="nsg-be-$name"
# Créer son groupe de ressources
New-AzResourceGroup -Location $location -Name $rg

# Commencer par créer les sous-réseaux du vnet (snet-be-name et snet-fe-name)
# Créer le réseau virtuel (vnet-name) et associer les deux sous réseaux
$objsnetfe=New-AzVirtualNetworkSubnetConfig -Name "$namesnetfe" -AddressPrefix $prefixsnetfe
$objsnetbe=New-AzVirtualNetworkSubnetConfig -Name $namesnetbe -AddressPrefix $prefixsnetbe
$objvnet=New-AzVirtualNetwork -Name $namevnet -Location $location  -ResourceGroupName $rg -AddressPrefix $prefixvnet -Subnet $objsnetfe,$objsnetbe

# Créer la règle AllowSSH pour autoriser le SSH depuis n'importe ou
# Créer le NSG de Back End en associant la règle à la création
# Associer le NSG au réseau de backEnd (ATTENTION NE PAS TOUCHER AU FE)
$objssh=New-AzNetworkSecurityRuleConfig -Name "SSH-Rule" -Description "Allow SSH" -Access Allow -Protocol * -Direction Inbound `
-Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix $prefixsnetbe -DestinationPortRange 22
$objnsg=New-AzNetworkSecurityGroup -Name $namensg -ResourceGroupName $rg -Location $location -SecurityRules $objssh
Set-AzVirtualNetworkSubnetConfig -Name $objsnetbe.Name -VirtualNetwork $objvnet -AddressPrefix $objsnetbe.AddressPrefix -NetworkSecurityGroup $objnsg
$objvnet | Set-AzVirtualNetwork

# Créer les deux machines virtuelles Debian et les mettres dans le réseau de BE.
# Bonus : Vous devez créer toutes ressources d'une machine virtuelle manuellement sauf le diskOS
# Bonus : Créer une boucle qui permet de créer un nombre de VM défini


for ($i=1;$i -le 2;$i++) {
    
$vmname="diallo$i"

$objpip=New-AzPublicIpAddress -Name "pip-$vmname" -ResourceGroupName $rg -Location $location -AllocationMethod Dynamic
$objnic=New-AzNetworkInterface -Name "nic-$vmname" -ResourceGroupName $rg -Location $location -PublicIpAddressId $objpip.Id -SubnetId $objvnet.Subnets[1].Id


$securepassword=ConvertTo-SecureString "P@ssw0rd2020" -AsPlainText -Force
$cred=New-Object System.Management.Automation.PSCredential ("formation",$securepassword)

$objconfvm=New-AzVMConfig -VMName "vm-$vmname" -VMSize "Standard_D1_v2" | `
Set-AzVMOperatingSystem -Linux -ComputerName "vm-$vmname" -Credential $cred | `
Set-AzVMSourceImage -PublisherName Debian -Offer debian-10 -Skus 10 -Version Latest | `
Add-AzVMNetworkInterface -Id $objnic.Id

New-AzVM -ResourceGroupName $rg -Location $location -VM $objconfvm
}


