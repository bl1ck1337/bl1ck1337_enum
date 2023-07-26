#!/bin/bash

# Collecting parametres

if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Tip: You can also provide parameters"
        read -p "Enter scope file: " scope_list
        read -p "Provide output directory name: " main_dir
else
        scope_list="$1"
        main_dir="$2"
fi

echo "
___.   .__  ____        __
\_ |__ |  |/_   | ____ |  | __
 | __ \|  | |   |/ ___\|  |/ /
 | \_\ \  |_|   \  \___|    <
 |___  /____/___|\___  >__|_ \
     \/              \/     \/
                        v1.0
 "

resolvers="/opt/bugbounty_tools/Wordlists/resolvers.txt"
regulator_py="/opt/bugbounty_tools/regulator/main.py"
temp_dir="$main_dir/temp_resolvers"
dns_bruteforce=""
logs_dir="$main_dir/logs"
resolved_subdomains="$main_dir/resolved_subdomains"
permutation_dir="$main_dir/permutation"
wayback_dir="$main_dir/wayback"
censys_dir="$main_dir/censys"
amass_dir="$main_dir/amass-scan"
subfinder_dir="$main_dir/subfinder-scan"
js_dir="$main_dir/javascript"
lives_dir="$main_dir/live_domain"

if [ ! -d "$permutation_dir" ] || [ ! -d "$subfinder_dir" ] || [ ! -d "$censys_dir" ] || [ ! -d "$temp_dir" ] || [ ! -d "$resolved_subdomains" ] || [ ! -d "$logs_dir" ]; then
        if [ ! -d "$permutation_dir" ];then
                mkdir "$permutation_dir"
        fi
        if [ ! -d "$logs_dir" ]; then
                mkdir "$logs_dir"
        fi
        if [ ! -d "$censys_dir" ]; then
                mkdir "$censys_dir"
        fi
        if [ ! -d "$subfinder_dir" ]; then
                mkdir "$subfinder_dir"
        fi
        if [ ! -d "$temp_dir" ]; then
                mkdir "$temp_dir"
        fi
        if [ ! -d "$resolved_subdomains" ]; then
                mkdir "$resolved_subdomains"
        fi
fi


# Runing Passive Tools: Amass, Subfinder, Censys

for target in $(cat scope.txt); do
        time=$(date +%T)
        echo
        echo -e "[$time] \033[32mCollecting Subdomain From Subfinder ...\033[0m"
        subfinder -d $target -all -silent -pc $HOME/.config/subfinder/provider-config.yaml -o "$subfinder_dir/subfinder-$target.txt"

        time=$(date +%T)
        echo
        echo -e "[$time] \033[32mCollecting Subdomain From Censys ...\033[0m"
        # Please Note That You Should Install Censys-Subdomain-Finder From Github
        python3 /opt/bugbounty_tools/censys-subdomain-finder/censys-subdomain-finder.py  --censys-api-id "xxxxxxxx-xxxxxxx-xxxxxxx" --censys-api-secret "xxxxxxxxxxxxxxx" $target >> "$censys_dir/censys-$target.txt"
        cat $censys_dir/censys-$target.txt | sed 's/  -//g' | sed 's/ //g' >> $censys_dir/filtred-censys-$target.txt
        rm $censys_dir/censys-$target.txt
        echo
        echo -e "[$time] \033[31mAll Passive Sources Was Finished ...\033[0m"

        time=$(date +%T)
        echo
        echo -e "[$time] \033[32mNow Collecting And Resolving All The Passive Subdomains ...\33[0m"
        cat "$censys_dir/filtred-censys-$target.txt" >> "$temp_dir/all_passive_subdomains.txt"
        cat "$subfinder_dir/subfinder-$target.txt" >> "$temp_dir/all_passive_subdomains.txt"

        time=$(date +%T)
        echo
        echo -e "[$time] \033[32mResolving Subdomains Using Massdns ...\33/0m"
        massdns -r $resolvers -t A -o S -w "$temp_dir/all_massdns.out" "$temp_dir/all_passive_subdomains.txt"

        time=$(date +%T)
        echo
        echo -e "[$time] \033[32mFiltring The Ip's And Subdomains ...\33[0m"
        cat "$temp_dir/all_massdns.out" | awk '{print $1}' | sed 's/.$//' | sort -u >> "$resolved_subdomains/online-hosts.txt"
        cat "$temp_dir/all_massdns.out" | awk '{print $3}' | sort -u | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" >> "$resolved_subdomains/online-ips.txt"

        time=$(date +%T)
        online_hosts="$resolved_subdomains/online-hosts.txt"
        line_count=$(wc -l < "$online_hosts")
        echo
        echo -e "[$time] \033[32mTotal of Resolved Subdomains: [$line_count]\033[0m"
        rm -rf "$temp_resolvers"
        rm -rf "$subfinder_dir"
        rm -rf "$censys_dir"
        sleep 2

        time=$(date +%T)
        echo
        echo -e "[$time] \033[32mPermutation Scan Was Start ...\033[0m"
        # Starting Permutation Scan Using Regex Of other resolved Subdomains Tequnique
        mkdir $main_dir/../logs
        touch $main_dir/../regulator.log
        touch $logs_dir/regulator.log
        python3 $regulator_py -t $target -f "$resolved_subdomains/online-hosts.txt" -o "$permutation_dir/regulator_$target.txt"

        time=$(date +%T)
        echo
        echo -e "[$time] \033[32mResolving Permutation Results ..\033[0m"
        #touch $logs_dir/regulator.log
        puredns resolve "$permutation_dir/regulator_$target.txt" --resolvers $resolvers --write "$permutation_dir/permutation_$target.valide"

        old_file="$resolved_subdomains/online-hosts.txt"
        new_file="$permutation_dir/permutation_$target.valide"
        cat "$new_file" >> "$old_file"
        anew "$old_file" < "$new_file"
        new_subdomains_count=$(grep -c -Fxf "$new_file" "$old_file")
        echo
        echo -e "[$time] \033[32mPermutation Was Finished with [$new_subdomains_count] New Subdomain ...\033[0m"


done