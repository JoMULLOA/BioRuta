# 🔍 Debug SSH Connection - BioRuta

## Problema detectado
- Puerto 1244 no responde desde GitHub Actions
- Conexiones SSH timeout
- Servidor responde a ping pero no a SSH

## Comandos para ejecutar EN EL SERVIDOR

⚠️ **DETECTADO: Entorno Docker sin systemd**

### Para entornos Docker (sin systemd):
```bash
# 1. Verificar si SSH está corriendo (Docker)
ps aux | grep ssh
service ssh status
/etc/init.d/ssh status

# 2. Verificar puertos activos
netstat -tlnp | grep :22
netstat -tlnp | grep :1244
ss -tlnp | grep :1244

# 3. Verificar configuración SSH
cat /etc/ssh/sshd_config | grep Port
ls -la /etc/ssh/

# 4. Verificar si SSH está instalado
which ssh
which sshd
dpkg -l | grep ssh

# 5. Información del contenedor
cat /etc/os-release
hostname
whoami
pwd

# 6. Ver procesos corriendo
ps aux
```

### Para instalar/configurar SSH en Docker:
```bash
# Instalar SSH
apt-get update
apt-get install -y openssh-server

# Configurar SSH
mkdir -p /var/run/sshd
echo 'Port 1244' >> /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

# Iniciar SSH
service ssh start
# o
/usr/sbin/sshd -D -p 1244 &
```

## Comandos para ejecutar DESDE TU MÁQUINA
```bash
# Probar con nmap
nmap -p 1244 146.83.198.35
nmap -p 22 146.83.198.35

# Probar diferentes puertos
for port in 22 1244 2222 2244; do
  echo "Puerto $port:"
  timeout 5 telnet 146.83.198.35 $port
done
```

## Posibles soluciones

### 1. SSH en puerto diferente
Si SSH está en puerto 22, cambiar el workflow:
```yaml
# Cambiar de puerto 1244 a 22
-e "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 -p 22"
```

### 2. Abrir puerto en firewall
```bash
# En el servidor
sudo ufw allow 1244/tcp
sudo iptables -A INPUT -p tcp --dport 1244 -j ACCEPT
```

### 3. Configurar SSH para puerto 1244
```bash
# Editar /etc/ssh/sshd_config
sudo nano /etc/ssh/sshd_config

# Agregar o cambiar:
Port 1244

# Reiniciar SSH
sudo systemctl restart ssh
```

## Estado actual
- ✅ Ping funciona
- ✅ **SSH funcionando en puerto 22** (no 1244)
- ✅ PM2 corriendo bajo usuario jmaureira
- ✅ SSH daemon activo (PID 24)
- 🔧 **SOLUCIONADO: Cambiar workflow a puerto 22**

## Alternativas para deployment en Docker

### Opción A: Configurar SSH en el contenedor
1. Instalar openssh-server en el contenedor
2. Configurar puerto 1244
3. Abrir puerto en el host Docker

### Opción B: API de deployment
```yaml
# En lugar de SSH, usar API REST para deployment
- name: 🚀 Deploy via API
  run: |
    curl -X POST http://146.83.198.35:3000/deploy \
      -H "Authorization: Bearer ${{ secrets.DEPLOY_TOKEN }}" \
      -d '{"branch": "main", "action": "deploy"}'
```

### Opción C: Docker exec directo
```yaml
# Si tienes acceso al Docker host
docker cp ./backend container_name:/app/
docker exec container_name pm2 restart all
```

### Opción D: Volúmenes compartidos
```bash
# Copiar a volumen compartido que el contenedor monte
rsync -avz ./backend/ /shared/volume/path/
# El contenedor detecta cambios automáticamente
```

## Próximos pasos INMEDIATOS:
1. 🔍 Ejecutar comandos de debug Docker en el servidor
2. 📋 Identificar la arquitectura real (¿contenedor? ¿host?)
3. 🔧 Decidir método de deployment apropiado:
   - SSH (configurar openssh-server)
   - API REST (más moderno)
   - Docker directo
   - Webhook deployment
