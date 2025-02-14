#!/bin/bash

CONFIG_FILE="/home/esteban/config_vms.conf"
DISK_DIR="/home/esteban/Documents/KVM" 

# Vérifier si le fichier de configuration existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Le fichier $CONFIG_FILE n'existe pas."
    exit 1
fi

sed -i 's/  */ /g' "$CONFIG_FILE"

# Lire et traiter chaque ligne du fichier de configuration
while IFS=' ' read -r VM_SOURCE VM_TARGET_PREFIX N_CLONES NETWORK RAM VCPU OS_VARIANT; do 
    echo "DEBUG: Champs séparés -> '${VM_SOURCE}' | '${VM_TARGET_PREFIX}' | '${N_CLONES}' | '${NETWORK}' | '${RAM}' | '${VCPU}' | '${OS_VARIANT}'"

    
    if [ -z "$VM_SOURCE" ] || [ -z "$VM_TARGET_PREFIX" ] || [ -z "$N_CLONES" ] || [ -z "$NETWORK" ] || [ -z "$RAM" ] || [ -z "$VCPU" ] || [ -z "$OS_VARIANT" ]; then
        echo "❌ Erreur : Une ou plusieurs valeurs sont vides dans cette ligne."
        continue
    fi

    # Ignorer les lignes vides ou celles qui commencent par #
    if [[ -z "$VM_SOURCE" || "$VM_SOURCE" =~ ^# || "$VM_SOURCE" == "VM_SOURCE" ]]; then
		continue
    fi


    echo "🚀 Clonage de $VM_SOURCE avec préfixe $VM_TARGET_PREFIX ($N_CLONES clones)"
    echo "➡️  Réseau : $NETWORK | RAM : ${RAM}MB | vCPU : ${VCPU} | OS : ${OS_VARIANT}"

    # Vérifier si la VM source existe
    if ! virsh list --all | grep -qw "$VM_SOURCE"; then
        echo "❌ Erreur : La VM $VM_SOURCE n'existe pas !"
        continue
    fi

    # Boucle pour créer le nombre de clones demandés
    for ((i=1; i<=N_CLONES; i++)); do
        VM_TARGET="${VM_TARGET_PREFIX}-$i"
        DISK_SOURCE="$DISK_DIR/$VM_SOURCE.qcow2"
        DISK_TARGET="$DISK_DIR/$VM_TARGET.qcow2"

        # Vérifier que le disque source existe
        if [ ! -f "$DISK_SOURCE" ]; then
            echo "❌ Erreur : Le fichier source $DISK_SOURCE n'existe pas !"
            continue
        fi

        echo "➡️  Création de $VM_TARGET..."

        # Copier l’image disque
        cp "$DISK_SOURCE" "$DISK_TARGET"

        # Créer la nouvelle VM avec `virt-install`
        virt-install --name "$VM_TARGET" \
            --ram "$RAM" \
            --vcpus "$VCPU" \
            --disk path="$DISK_TARGET",format=qcow2 \
            --network network="$NETWORK" \
            --os-variant "$OS_VARIANT" \
            --graphics none \
            --import \
            --noautoconsole

        # Vérifier si le clonage a réussi
        if [ $? -eq 0 ]; then
            echo "✅ Clonage réussi : $VM_TARGET créé."
        else
            echo "❌ Échec du clonage de $VM_SOURCE vers $VM_TARGET."
            continue
        fi

        # 🚀 Démarrer la VM
        virsh start "$VM_TARGET"
        echo "✅ $VM_TARGET a été démarré avec succès."

        # 🔧 Attacher l'interface réseau après le démarrage
        sleep 5  # Attendre 5 secondes pour s'assurer que la VM est bien lancée
        virsh attach-interface --domain "$VM_TARGET" --type network --source "$NETWORK" --config --live

        echo "➡️  Interface réseau $NETWORK attachée à $VM_TARGET."
        echo "----------------------------------------"
    done
done < "$CONFIG_FILE"

