VIP=192.168.1.100
SAM=192.168.1.101
CLOVER=192.168.1.102
ALEX=192.168.1.103

talosctl -n $VIP etcd members

mv clusterconfig/woohp-sam.yaml clusterconfig/woohp-sam.yaml.bak
mv clusterconfig/woohp-clover.yaml clusterconfig/woohp-clover.yaml.bak
mv clusterconfig/woohp-alex.yaml clusterconfig/woohp-alex.yaml.bak
mv clusterconfig/talosconfig clusterconfig/talosconfig.bak

talhelper genconfig


echo "========================================"
echo "=== Reviewing SAM Node Configuration ==="
echo "========================================\n"
diff --color -u clusterconfig/woohp-sam.yaml.bak clusterconfig/woohp-sam.yaml || true
echo ""
read -p "Apply configuration to SAM node? (y/n): " SAM_CONFIRMATION

if [[ "$SAM_CONFIRMATION" == "y" ]]; then
    talosctl apply-config -e $SAM -n $SAM --file clusterconfig/woohp-sam.yaml
    echo "✓ SAM configuration applied"
else
    cp clusterconfig/woohp-sam.yaml.bak clusterconfig/woohp-sam.yaml
    echo "✗ SAM configuration skipped"
fi

echo ""


echo "==========================================="
echo "=== Reviewing CLOVER Node Configuration ==="
echo "==========================================="
diff --color -u clusterconfig/woohp-clover.yaml.bak clusterconfig/woohp-clover.yaml || true
echo ""
read -p "Apply configuration to CLOVER node? (y/n): " CLOVER_CONFIRMATION

if [[ "$CLOVER_CONFIRMATION" == "y" ]]; then
    talosctl apply-config -e $CLOVER -n $CLOVER --file clusterconfig/woohp-clover.yaml
    echo "✓ CLOVER configuration applied"
else
    cp clusterconfig/woohp-clover.yaml.bak clusterconfig/woohp-clover.yaml
    echo "✗ CLOVER configuration skipped"
fi

echo ""


echo "========================================="
echo "=== Reviewing ALEX Node Configuration ==="
echo "=========================================\n"
diff --color -u clusterconfig/woohp-alex.yaml.bak clusterconfig/woohp-alex.yaml || true
echo ""
read -p "Apply configuration to ALEX node? (y/n): " ALEX_CONFIRMATION

if [[ "$ALEX_CONFIRMATION" == "y" ]]; then
    talosctl apply-config -e $ALEX -n $ALEX --file clusterconfig/woohp-alex.yaml
    echo "✓ ALEX configuration applied"
else
    cp clusterconfig/woohp-alex.yaml.bak clusterconfig/woohp-alex.yaml
    echo "✗ ALEX configuration skipped"
fi


talosctl -n $VIP etcd members
