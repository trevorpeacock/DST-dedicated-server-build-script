#!/usr/bin/bash

################################################################
#
# Set up DST server
# -----------------
#
#
#
# Create and EC2 Instance with the following settings
# Ubuntu Server 20.04 LTS (ami-0567f647e75c7bc05)
# t3a.medium
# 12GB disk
# Security group allowing SSH (TCP/22) DST (UDP/11000) and Ping (ICMP Echo Request)
#
# Fill in CLUSTER_TOKEN and GAME_NAME parameters below, and run script
#
################################################################

# Klei server token
# visit https://accounts.klei.com/account/game/servers?game=DontStarveTogether
CLUSTER_TOKEN=""

# Server name published in DST game browser
GAME_NAME=""
GAME_DESCRIPTION=""

# DST Parameters
GAME_MODE="endless"
GAME_MAX_PLAYERS="6"
GAME_PVP="false"
GAME_INTENTION="cooperative"
# Password optional
GAME_PASSWORD=""

# Sets up a script to shut down the server if no one is connected
ENABLE_AUTO_SHUTDOWN=true
# How many minutes should the server stay running after last person disconnects
AUTO_SHUTDOWN_TIME=90


################################################################
#
# FILE DEFINITIONS
# ----------------
#
#
################################################################

function write_dst_service_file
{
FILE_NAME=/etc/systemd/system/dst.service
sudo tee $FILE_NAME > /dev/null <<EOT
[Unit]
Description=Don't Starve Together Dedicated Server
Wants=network-online.target
After=network.target network-online.target

[Service]
ExecStart=/home/steam/run_dedicated_servers.sh
Restart=on-failure
User=steam

[Install]
WantedBy=multi-user.target
EOT
}

################################################################

function write_dst_startup_script
{
FILE_NAME=/home/steam/run_dedicated_servers.sh
sudo tee $FILE_NAME > /dev/null <<EOT
#!/bin/bash

steamcmd_dir="\$HOME/steamcmd"
install_dir="\$HOME/dontstarvetogether_dedicated_server"
cluster_name="MyDediServer"
dontstarve_dir="\$HOME/.klei/DoNotStarveTogether"

if [ ! -d \$steamcmd_dir ]
then
  mkdir -p ~/steamcmd/
  cd ~/steamcmd/
  wget "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -O ~/steamcmd/steamcmd_linux.tar.gz
  tar -C ~/steamcmd/ -xvzf ~/steamcmd/steamcmd_linux.tar.gz
fi

function fail()
{
	echo Error: "\$@" >&2
	exit 1
}

function check_for_file()
{
	if [ ! -e "\$1" ]; then
		fail "Missing file: \$1"
	fi
}

cd "\$steamcmd_dir" || fail "Missing \$steamcmd_dir directory!"

check_for_file "steamcmd.sh"
check_for_file "\$dontstarve_dir/\$cluster_name/cluster.ini"
check_for_file "\$dontstarve_dir/\$cluster_name/cluster_token.txt"
check_for_file "\$dontstarve_dir/\$cluster_name/Master/server.ini"
check_for_file "\$dontstarve_dir/\$cluster_name/Caves/server.ini"

./steamcmd.sh +force_install_dir "\$install_dir" +login anonymous +app_update 343050 validate +quit

check_for_file "\$install_dir/bin64"

cd "\$install_dir/bin64" || fail

MODS_INSTALL_FILE=\$install_dir/mods/dedicated_server_mods_setup.lua
function add_mod
{
  grep \$1 \$MODS_INSTALL_FILE > /dev/null || echo "ServerModSetup(\"\$1\")" | tee -a \$MODS_INSTALL_FILE > /dev/null
}

function add_mods_from
{
  grep -o "\[\"workshop-[0-9]\+\"\]" \$1 | sed -r "s/\[\"workshop-([0-9]+)\"\]/\1/" | while read mod_id
  do
    add_mod \$mod_id
  done
}
add_mods_from "\$dontstarve_dir/\$cluster_name/Master/modoverrides.lua"
add_mods_from "\$dontstarve_dir/\$cluster_name/Caves/modoverrides.lua"

run_shared=(./dontstarve_dedicated_server_nullrenderer_x64)
run_shared+=(-console)
run_shared+=(-cluster "\$cluster_name")
run_shared+=(-monitor_parent_process \$\$)

"\${run_shared[@]}" -shard Caves  | sed 's/^/Caves:  /' &
"\${run_shared[@]}" -shard Master | sed 's/^/Master: /'
EOT
sudo chown steam:steam $FILE_NAME
sudo chmod +x $FILE_NAME
}

################################################################

function write_autoshutdown_cron_config
{
FILE_NAME=/etc/cron.d/auto_shutdown.cron
sudo tee $FILE_NAME > /dev/null <<EOT
* * * * * root /home/steam/auto_shutdown.sh
EOT
}

################################################################

function write_autoshutdown_script
{
FILE_NAME=/home/steam/auto_shutdown.sh
sudo tee $FILE_NAME > /dev/null <<EOT
#!/bin/bash

TIMEOUT=$AUTO_SHUTDOWN_TIME

if [ `sed -r "s/^([0-9]+).*/\1/g" /proc/uptime` -lt 1800 ]
then
  echo "System rebooted recently, not proceeding with idle check."
  exit 0
fi


if ( ! find /home/steam/.klei/ -mmin -\$TIMEOUT -type f | grep -v server_log.txt > /dev/null)
then
  echo "No change in \$TIMEOUT minutes, shutting down server."
  systemctl stop dst
  sleep 20
  #sudo su - steam -c /home/steam/backup.sh
  /usr/sbin/shutdown -h now
fi
EOT
sudo chown steam:steam $FILE_NAME
sudo chmod +x $FILE_NAME
}

################################################################

function write_game_cluster_ini
{
FILE_NAME=/home/steam/.klei/DoNotStarveTogether/MyDediServer/cluster.ini
sudo tee $FILE_NAME > /dev/null <<EOT
[GAMEPLAY]
game_mode = $GAME_MODE
max_players = $GAME_MAX_PLAYERS
pvp = $GAME_PVP
pause_when_empty = true

[NETWORK]
cluster_description = $GAME_DESCRIPTION
cluster_name = $GAME_NAME
cluster_intention = $GAME_INTENTION
cluster_password = $GAME_PASSWORD

[MISC]
console_enabled = true

[SHARD]
shard_enabled = true
bind_ip = 127.0.0.1
master_ip = 127.0.0.1
master_port = 10889
cluster_key = supersecretkey
EOT
sudo chown steam:steam $FILE_NAME
}

################################################################

function write_game_cluster_token
{
FILE_NAME=/home/steam/.klei/DoNotStarveTogether/MyDediServer/cluster_token.txt
sudo tee $FILE_NAME > /dev/null <<EOT
$CLUSTER_TOKEN
EOT
sudo chown steam:steam $FILE_NAME
}

################################################################

function write_game_master_server_ini
{
FILE_NAME=/home/steam/.klei/DoNotStarveTogether/MyDediServer/Master/server.ini
sudo tee $FILE_NAME > /dev/null <<EOT
[NETWORK]
server_port = 11000

[SHARD]
is_master = true

[STEAM]
master_server_port = 27018
authentication_port = 8768
EOT
sudo chown steam:steam $FILE_NAME
}

################################################################

function write_game_caves_server_ini
{
FILE_NAME=/home/steam/.klei/DoNotStarveTogether/MyDediServer/Caves/server.ini
sudo tee $FILE_NAME > /dev/null <<EOT
[NETWORK]
server_port = 11001

[SHARD]
is_master = false
name = Caves

[STEAM]
master_server_port = 27019
authentication_port = 8769
EOT
sudo chown steam:steam $FILE_NAME
}

################################################################

function write_game_master_worldgenoverride_lua
{
FILE_NAME=/home/steam/.klei/DoNotStarveTogether/MyDediServer/Master/worldgenoverride.lua
sudo tee $FILE_NAME > /dev/null <<EOT
return {
}
EOT
sudo chown steam:steam $FILE_NAME
}

################################################################

function write_game_caves_worldgenoverride_lua
{
FILE_NAME=/home/steam/.klei/DoNotStarveTogether/MyDediServer/Caves/worldgenoverride.lua
sudo tee $FILE_NAME > /dev/null <<EOT
return {
    override_enabled = true,
    preset = "DST_CAVE",
}
EOT
sudo chown steam:steam $FILE_NAME
}

################################################################

function write_game_master_modoverrides_lua
{
FILE_NAME=/home/steam/.klei/DoNotStarveTogether/MyDediServer/Master/modoverrides.lua
sudo tee $FILE_NAME > /dev/null <<EOT
return {
}
EOT
sudo chown steam:steam $FILE_NAME
}

################################################################

function write_game_caves_modoverrides_lua
{
FILE_NAME=/home/steam/.klei/DoNotStarveTogether/MyDediServer/Caves/modoverrides.lua
sudo tee $FILE_NAME > /dev/null <<EOT
return {
}
EOT
sudo chown steam:steam $FILE_NAME
}

################################################################

function write_game_admins
{
FILE_NAME=/home/steam/.klei/DoNotStarveTogether/MyDediServer/adminlist.txt
sudo tee $FILE_NAME > /dev/null <<EOT
EOT
sudo chown steam:steam $FILE_NAME
}

################################################################
#
# SERVER_SETUP
# ------------
#
#
################################################################

echo "Checking parameters"
if [ "$GAME_NAME" = "" ]; then
  echo "GAME_NAME not set. Update variable at top of $(basename $0) and rerun"
  exit 1
fi

if [ "$CLUSTER_TOKEN" = "" ]; then
  echo "CLUSTER_TOKEN not set. Update variable at top of $(basename $0) and rerun"
  exit 1
fi

OVERWRITE_GAME_CONFIG=false
DONT_START=false
LAUNCH=false

print_usage() {
  echo "Usage: $(basename $0) [-o] [-d] [-l]"
  echo ""
  echo " $(basename $0) will set up a DST service and start it"
  echo ""
  echo "  Arguments:"
  echo "    -o overwite game configuration if it exists"
  echo "    -d don't start the dst service"
  echo "    -l launch the server interactively (implies -d)"
}

while getopts 'odl' flag; do
  case "${flag}" in
    o) OVERWRITE_GAME_CONFIG='true' ;;
    d) DONT_START='true' ;;
    l) LAUNCH='true' ;;
    *) print_usage
       exit 1 ;;
  esac
done

echo "Installing packages"
sudo timedatectl set-timezone Australia/Sydney
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y lib32gcc1 lib32stdc++6 libstdc++6:i386 libgcc1:i386 libcurl4-gnutls-dev:i386

echo ""

if [ ! -d /home/steam ]
then
  echo "Creating Steam User"
  sudo useradd -m steam -s /usr/bin/bash
fi

write_dst_startup_script
write_dst_service_file
sudo systemctl daemon-reload
sudo systemctl enable dst.service

if [ "$ENABLE_AUTO_SHUTDOWN" = true ]
then
  echo "Writing auto-shutdown config"
  write_autoshutdown_cron_config
  write_autoshutdown_script
  sudo service cron reload
fi

if [ ! -d /home/steam/.klei/DoNotStarveTogether/MyDediServer/ ] || [ "$OVERWRITE_GAME_CONFIG" = "true" ]
then
  echo "Writing game config"
  sudo mkdir -p /home/steam/.klei/DoNotStarveTogether/MyDediServer/
  sudo mkdir -p /home/steam/.klei/DoNotStarveTogether/MyDediServer/Caves
  sudo mkdir -p /home/steam/.klei/DoNotStarveTogether/MyDediServer/Master
  sudo chown steam:steam /home/steam/.klei/DoNotStarveTogether/MyDediServer/
  sudo chown steam:steam /home/steam/.klei/DoNotStarveTogether/MyDediServer/Caves
  sudo chown steam:steam /home/steam/.klei/DoNotStarveTogether/MyDediServer/Master

  write_game_cluster_ini
  write_game_cluster_token
  write_game_master_server_ini
  write_game_caves_server_ini
  write_game_master_worldgenoverride_lua
  write_game_caves_worldgenoverride_lua
  write_game_master_modoverrides_lua
  write_game_caves_modoverrides_lua
  write_game_admins
fi

if [ ! "$DONT_START" = "true" ] && [ ! "$LAUNCH" = "true" ]
then
  echo "Starting service"
  sudo systemctl start dst
  echo "Server will take several minutes to start first time (5 min or more, depending on server and connection). Check logs for status"
fi

if [ "$LAUNCH" = "true" ]
then
  echo "Launching Server"
  sudo su - steam -c /home/steam/run_dedicated_servers.sh
fi

echo ""
echo "To view the service status run"
echo "systemctl status dst"
echo ""
echo "To restart the server (after config change) run"
echo "systemctl restart dst"
echo ""
echo "To view logs run"
echo "journalctl -u dst"
echo ""
echo "To tail logs run"
echo "journalctl -f -u dst"
echo ""
echo ""
echo "Don't forget to open port in firewall"
grep "^server_port \?=" /home/steam/.klei/DoNotStarveTogether/MyDediServer/Master/server.ini
echo "The Game password is"
grep cluster_password /home/steam/.klei/DoNotStarveTogether/MyDediServer/cluster.ini
