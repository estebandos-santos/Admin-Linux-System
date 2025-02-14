import os
import subprocess
import time

CONFIG_FILE = "/home/esteban/config_vms.conf"
DISK_DIR = "/home/esteban/Documents/KVM"  

# Vérifier si le fichier de configuration existe
if not os.path.isfile(CONFIG_FILE):
    print(f"\u274C Le fichier {CONFIG_FILE} n'existe pas.")
    exit(1)

# Lire et traiter chaque ligne du fichier de configuration
with open(CONFIG_FILE, 'r') as config_file:
    for line in config_file:
        # Ignorer les lignes vides ou celles qui commencent par #
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        # Séparer les valeurs
        values = line.split()
        if len(values) != 6:
            print("❌ Erreur : Ligne invalide dans le fichier de configuration.")
            continue

        VM_SOURCE, VM_TARGET_PREFIX, N_CLONES, NETWORK, RAM, VCPU = values

        # Convertir les valeurs numériques
        try:
            N_CLONES = int(N_CLONES)
            RAM = int(RAM)
            VCPU = int(VCPU)
        except ValueError:
            print("❌ Erreur : Les valeurs numériques ne sont pas correctes.")
            continue

        print(f"🚀 Clonage de {VM_SOURCE} avec préfixe {VM_TARGET_PREFIX} ({N_CLONES} clones)")
        print(f"➡️  Réseau : {NETWORK} | RAM : {RAM}MB | vCPU : {VCPU}")

        # Vérifier si la VM source existe
        result = subprocess.run(["virsh", "list", "--all"], capture_output=True, text=True)
        if VM_SOURCE not in result.stdout:
            print(f"❌ Erreur : La VM {VM_SOURCE} n'existe pas !")
            continue

        # Boucle pour créer le nombre de clones demandés
        for i in range(1, N_CLONES + 1):
            VM_TARGET = f"{VM_TARGET_PREFIX}-{i}"
            DISK_SOURCE = os.path.join(DISK_DIR, f"{VM_SOURCE}.qcow2")
            DISK_TARGET = os.path.join(DISK_DIR, f"{VM_TARGET}.qcow2")

            # Vérifier que le disque source existe
            if not os.path.isfile(DISK_SOURCE):
                print(f"❌ Erreur : Le fichier source {DISK_SOURCE} n'existe pas !")
                continue

            print(f"➡️  Création de {VM_TARGET}...")
            subprocess.run(["cp", DISK_SOURCE, DISK_TARGET])

            # Créer la nouvelle VM avec `virt-install`
            result = subprocess.run([
                "virt-install", "--name", VM_TARGET,
                "--ram", str(RAM),
                "--vcpus", str(VCPU),
                "--disk", f"path={DISK_TARGET},format=qcow2",
                "--network", f"network={NETWORK}",
                "--os-variant", "ubuntu22.04",
                "--graphics", "none",
                "--import",
                "--noautoconsole"
            ])

            if result.returncode == 0:
                print(f"✅ Clonage réussi : {VM_TARGET} créé.")
            else:
                print(f"❌ Échec du clonage de {VM_SOURCE} vers {VM_TARGET}.")
                continue

            # Démarrer la VM
            subprocess.run(["virsh", "start", VM_TARGET])
            print(f"✅ {VM_TARGET} a été démarré avec succès.")

            # Attacher l'interface réseau après le démarrage
            time.sleep(5)  # Attendre 5 secondes
            subprocess.run(["virsh", "attach-interface", "--domain", VM_TARGET, "--type", "network", "--source", NETWORK, "--config", "--live"])

            print(f"➡️  Interface réseau {NETWORK} attachée à {VM_TARGET}.")
            print("----------------------------------------")
