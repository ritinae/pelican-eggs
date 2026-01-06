#! /usr/bin/env bash
apt update -y
apt install \
	-y \
	--no-install-recommends \
	--no-install-suggests \
	wget jq

if [ "$STEAM_USER" == "" ]; then
	echo "steam user is not set."
	echo "Using anonymous user."
	: "${STEAM_USER:=anonymous}"
	: "${STEAM_PASS:=}"
	: "${STEAM_AUTH:=}"
else
	echo "user set to $STEAM_USER"
fi

## download and install steamcmd
mkdir -p /mnt/server/steamcmd
curl -sSL -o /tmp/steamcmd.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
tar -xzvf /tmp/steamcmd.tar.gz -C /mnt/server/steamcmd

cd /mnt/server/steamcmd || exit 1

# SteamCMD fails otherwise for some reason, even running as root.
# This is changed at the end of the install process anyways.
chown -R root:root /mnt
export HOME=/mnt/server

## install game using steamcmd
./steamcmd.sh \
	+force_install_dir \
	/mnt/server \
	+login "$STEAM_USER" "$STEAM_PASS" "$STEAM_AUTH" \
	+app_update 896660 \
	+quit

## set up libraries for steam client
mkdir -p /mnt/server/.steam/sdk{32,64}
cp -v linux32/steamclient.so ../.steam/sdk32/steamclient.so
cp -v linux64/steamclient.so ../.steam/sdk64/steamclient.so

echo "-------------------------------------------------------"
echo "installing BepInEx and Selected ModPacks..."
echo "-------------------------------------------------------"

cd /mnt/server || exit 1

BEPINEX_URL="https://thunderstore.io/api/experimental/package/denikson/BepInExPack_Valheim/"
if ! BEPINEX_MANIFEST=$(curl -sfSL -H "accept: application/json" "$BEPINEX_URL"); then
	echo "Error: could not retrieve BepInEx release info from Thunderstore.io API"
	exit 1
fi

DOWNLOAD_MIRROR="https://thunderstore.io/package/download"
PLUGIN_DIR="/mnt/server/BepInEx/plugins"
CONFIG_DIR="/mnt/server/BepInEx/config"
DOWNLOAD_DIR="/mnt/server/tmp_dl"

BEPINEX_MOD_URL=$(jq -r  ".latest.download_url" <<< "$BEPINEX_MANIFEST" )
BEPINEX_MOD="denikson-BepInExPack_Valheim"
BEPINEX_INSTALL_DIR="/mnt/server"

# Ensure directories exist
mkdir -p "$BEPINEX_INSTALL_DIR" "$DOWNLOAD_DIR" "$PLUGIN_DIR" "$CONFIG_DIR"

wget --content-disposition -O "$DOWNLOAD_DIR/$BEPINEX_MOD.zip" "$BEPINEX_MOD_URL"
unzip -o "$DOWNLOAD_DIR/$BEPINEX_MOD.zip" -d "$DOWNLOAD_DIR"

cp -rf "$DOWNLOAD_DIR/BepInExPack_Valheim/"{doorstop_config.ini,doorstop_libs,BepInEx,winhttp.dll} "$BEPINEX_INSTALL_DIR/"
cp -rf "$DOWNLOAD_DIR/BepInExPack_Valheim/BepInEx" "$BEPINEX_INSTALL_DIR/"


if [ ! -z "$V_MODPACK" ]; then
	#Modpack Name dashes to slashes for URL
	MODPACK_URL=$(echo "$V_MODPACK" | sed 's/-/\//g')

	# Download and extract modpack. The modpack itself may technically contain
	# assets/overrides, so it is safest to place it inside the plugin dir.
	wget -O "$DOWNLOAD_DIR/$V_MODPACK.zip" "$DOWNLOAD_MIRROR/$MODPACK_URL"
	unzip -o "$DOWNLOAD_DIR/$V_MODPACK.zip" -d "$PLUGIN_DIR/$V_MODPACK"

	#Extract dependencies from ModPack JSON manifest
	MODPACK_DEPS=$(cat "$PLUGIN_DIR/$V_MODPACK/manifest.json" | jq -r '.dependencies[]')

	for MOD in $MODPACK_DEPS; do
		# Ignore BepInEx, it was already installed
		if [[ "$MOD" == *"denikson-BepInExPack_Valheim"* ]]; then
			continue
		fi

		# Dowload and extract. Extract all files, as e.g. asset bundles may need
		# to be present within the plugin directories.
		MOD_URL=$(echo "$MOD" | sed 's/-/\//g')
		MOD_DIR="$PLUGIN_DIR/$MOD"
		wget -O "$DOWNLOAD_DIR/$MOD.zip" "$DOWNLOAD_MIRROR/$MOD_URL"
		rm -rf "${MOD_DIR:?}"
		unzip -o "$DOWNLOAD_DIR/$MOD.zip" -d "$MOD_DIR"

		# Install mod configs
		if [ -d "$MOD_DIR/config" ]; then
			cp -rf "$MOD_DIR/config" "/mnt/server/BepInEx"
		# HACK: funky casing on some mods
		elif [ -d "$PLUGIN_DIR/$V_MODPACK/Config" ]; then
			cp -rf -t "/mnt/server/BepInEx/config" "$PLUGIN_DIR/$V_MODPACK/Config/*"
		fi
	done

	# Install modpack configs last to make sure the modpack can override any
	# files extracted from other mods.
	if [ -d "$PLUGIN_DIR/$V_MODPACK/config" ]; then
		cp -rf "$PLUGIN_DIR/$V_MODPACK/config" "/mnt/server/BepInEx"
	# HACK: funky casing on some mods
	elif [ -d "$PLUGIN_DIR/$V_MODPACK/Config" ]; then
		cp -rf -t "/mnt/server/BepInEx/config" "$PLUGIN_DIR/$V_MODPACK/Config/*"
	fi
fi

echo "-------------------------------------------------------"
echo "Cleaning up..."
echo "-------------------------------------------------------"

rm -rf "${DOWNLOAD_DIR:?}"

echo "-------------------------------------------------------"
echo "Installation completed"
echo "-------------------------------------------------------"
