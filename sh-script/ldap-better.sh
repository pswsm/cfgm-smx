#!/usr/bin/env bash

_script="$(readlink -f ${BASH_SOURCE[0]})"
_base="$(dirname $_script)"

fusers="$_base/users.ldif"
fuos="$_base/uos.ldif"
fgroups="$_base/groups.ldif"
fall="$_base/all.ldif"
dname="$_base/.dname"
topdn="$_base/.topdn"
fadmin="$_base/.admin"

# Loop Principal
while :
do
	clear
	if [[ ! -f $fadmin  || ! -f $topdn ]]; then
		printf "\nEscriu el teu domnini (example.com):\t\t"
		IFS=. read domainname tls
		printf "\nEscriu l'usuari amb el que s'administra el domini (ex: Admin):\t"
		read adminuser
		printf "cn=%s,dc=%s,dc=%s" $adminuser $domainname $tls > $fadmin
		printf "dc=%s,dc=%s" $domainname $tls > $topdn
		printf "%s.%s" $domainname $tls > $dname
		unset domainname tls adminuser
	fi

	clear
	printf "░▒█░░░░█▀▄░█▀▀▄░▄▀▀▄░░░▒█▀▄▀█░█▀▀░█▀▀▄░█░▒█░░░▒█░▒█░█▀▀░█░░▄▀▀▄░█▀▀░█▀▀▄\n░▒█░░░░█░█░█▄▄█░█▄▄█░░░▒█▒█▒█░█▀▀░█░▒█░█░▒█░░░▒█▀▀█░█▀▀░█░░█▄▄█░█▀▀░█▄▄▀\n░▒█▄▄█░▀▀░░▀░░▀░█░░░░░░▒█░░▒█░▀▀▀░▀░░▀░░▀▀▀░░░▒█░▒█░▀▀▀░▀▀░█░░░░▀▀▀░▀░▀▀\n\n"

	printf "\n\t(1) Crear nova UO\n\t(2) Crear un nou grup\n\t(3) Crear un nou usuari\n\t(4) Carregar a LDAP\n\t(5) Sortir\n"
	read choice

	case $choice in
		5 )
		exit 0
			;;
		4 )
		# Load Files
		clear
		printf "Que vols carregar a la Base de Dades?\n"
		printf "\n\t1: Usuaris\n\t2: UOs\n\t3: Grups\n\t4: Tot\n"
		read choice
		case choice in
			1 )
			#Load users
			printf "Es carregaran els usuaris.\n"
			printf "Escriu la contrasenya d'LDAP:\t"
			read -s contrasenya
			ldapadd -x -w $contrasenya -D $fadmin -f $fusers
				;;
			2)
			#Load OUs
			printf "Es carregaran les UOs.\n"
			printf "Escriu la contrasenya d'LDAP:\t"
			read -s contrasenya
			ldapadd -x -w $contrasenya -D $fadmin -f $fuos
				;;
			3)
			#Load Groups
			printf "Es carregaran els grups.\n"
			printf "Escriu la contrasenya d'LDAP:\t"
			read -s contrasenya
			ldapadd -x -w $contrasenya -D $fadmin -f $fgroups
				;;
			3)
			#Load All
			printf "Es carregarà tot.\n"
			printf "Escriu la contrasenya d'LDAP:\t"
			read -s contrasenya
			cat $fuos $fgroups $fusers > $fall
			ldapadd -x -w $contrasenya -D $fadmin -f $fall
				;;
		esac
			;;
		3 )
		# User Creation
		## Get uidnum
		uid=999
		if [[ -f $fusers ]]; then
			uifile=$(grep uidNumber $fusers | cut -d " " -f2 | sort -d | tail -n 1)
			uidb=$(ldapsearch -x -LLL -b $(cat $topdn) "(objectClass=inetOrgPerson)" | grep uidNumber | sort -d | cut -d " " -f2 | tail -n 1)
			((uifile++))
			((uidb++))
			if [ $uifile > $uidb ]; then
				uid=$uifile
			else
				uid=$uidb
			fi
		else
			uid=$(ldapsearch -x -LLL -b $(cat $topdn) "(objectClass=inetOrgPerson)" | grep uidNumber | sort -d | cut -d " " -f2 | tail -n 1)
			((uid++))
		fi
		printf "\nL\'arxiu d\'usuaris es guardarà a %s\nNom i 1r congnom de l\'usuari: " $fusers
		IFS=" " read -a nomcg
		printf "dn: cn=%s %s" ${nomcg[@]} >> $fusers
		printf "\nUbicació de l\'usuari en el domini (Per defecte %s)(uo.domini.tls): " $(cat $dname)
		IFS=. read -a dn
		printf "\n\n" | printf "ou=%s," ${dn[@]::${#dn[@]}-2} >> $fusers
		printf "dn=%s," ${dn[-2]} ${dn[-1]} | sed 's/.$//' >> $fusers
		printf "\ncn: %s %s"  ${nomcg[@]} >> $fusers
		printf "\ngivenName: %s" ${nomcg[1]}
		printf "\nEstà en algún grup? [Y/n] "
		read yn
		case $yn in
			* )
			namefr=( $(ldapsearch -x -LLL -b $(cat $topdn) "(objectClass=posixGroup)" | cut -d ' ' -f2 | cut -d ',' -f1 | sed 's/cn=//' | uniq | sed '/^[[:digit:]]*$/d;/posixGroup/d;/top/d' | sort -d) )
			gidfor=( $(ldapsearch -x -LLL -b $(cat $topdn) "(objectClass=posixGroup)" | cut -d ' ' -f2 | cut -d ',' -f1 | sed 's/cn=//' | uniq | sed '/^[a-zA-Z]*$/d;/posixGroup/d;/top/d' | sort -d) )
			for i in ${namefr[@]}; do
				arr[${gidfor[i]}]=${namefr[i]}
				i++
			done
			printf "%s" ${arr[@]}
			printf "\n\nEn quin grup està? (Introdueix el gid): "
			read gidUSR
				;;
			N | n )
			printf "Ah bé, tu sabràs manet"
		esa

			;;
	esac

done
