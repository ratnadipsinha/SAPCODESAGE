import pyrfc, os, yaml

cfg  = yaml.safe_load(open('scan_config.yaml'))
conn = pyrfc.Connection(
    ashost=cfg['sap']['host'],   sysnr=cfg['sap']['sysnr'],
    client=cfg['sap']['client'], user=cfg['sap']['user'],
    passwd=os.environ['SAP_RFC_PASSWORD'])

result = conn.call('RFC_PING')
print('RFC connection successful:', result)
# Expected output:  RFC connection successful: {}
