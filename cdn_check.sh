#!/bin/bash
version='0.2.19'
#useragent=${useragent-"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"}
#useragent=${useragent-"Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1"}
useragent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.71 Safari/537.36 Edg/97.0.1072.55"
CURLARG='--connect-timeout 10 -s --compressed'
curl_format='\n%{time_namelookup},%{time_connect},%{time_appconnect},%{time_pretransfer},%{time_redirect},%{time_starttransfer},%{time_total},%{speed_download},%{http_code}'
curl_format2='\n%{time_namelookup},%{time_connect},%{time_appconnect},%{time_pretransfer},%{time_redirect},%{time_starttransfer},%{time_total},%{speed_download},%{http_code},%{remote_ip},%{remote_port}'
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)
ChangeLog="
0.2.15: fix error in host command reset connect
0.2.16: Modify exit to return after host get empty data
0.2.17: Modify dig format
    Add -n2 , -n3 , dig +trace 
0.2.18: fix http header display bug
0.2.19: add -1(showhead), -2(showbody), fix hostname bug, fix showhead and -v bug
"

[ -f /usr/local/bin/curl ] && CURL=/usr/local/bin/curl
CURL=${CURL-/usr/bin/curl}
if [ $( $CURL --version | awk '/^curl/{ print $2 }' | tr -d "." ) -lt 7214 ] ; then
    echo "Please Upgrade curl version >= 7.21.3"
    exit 1;
fi
print_help(){
    cat <<EOF
$0 [OPTIONS] [ curl options args ] [target site]
    [target site]    Target site domain name,default apple.com

Version: $version

OPTIONS:
    -b          Background run,interval 60s
    -h          this help
    -n          dnstracer 快速查詢(快, 但會有查不出結果的問題, 如果 IP 為空值，請用 -n2 代替)
    -n2        dnstracer 嚴謹查詢(較慢）
    -n3        使用 dig +tracer (較快, 但無法確認 name server 是否正常)
    -v          curl -v 相等，不建議再開 -showhead
    -simp       curl 只有針對域名測試，
                不會單獨測試每個 IP,
                會有正確的 curl dns 查詢時間
    -showhead or -1   dump http repone header
    -showbody or -2   show http body
    -version    show version
    -ws        WebSocket protocol
    -wsk    Added header Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==
    -w [sec]    interval, default 1s
    -c [num]    loop count,default 1,0 =  keep run
    -d [ dns ip ]    指定 dns server
    -A [useragent]    UserAgent UserAgent
    -x [ proxy ]    Proxy Server,可以用 5::1086 or 5:127.0.0.1:1086 替代 socks5://127.0.0.1:1086
                    註: socks5 才有支援查詢 dns 回應的每個個 IP
    -r [ ip ]    指定 ip
    -H [ curl custom header ]     curl custom header
EOF
}

while [[ $# -gt 0 ]] ; do
    # interval default 60s
#    echo "ARG: $1"
#    echo "ARGS: ${args[@]}"
    case "$1" in
        "-simp")
            simp=1
            ;;
        '-showhead'|'-1')
            show=1
            args+=( "-D-" )
            ;;
        '-showbody'|'-2')
            show=1
            bodyout="-"
            ;;
        '-version')
            echo -e "Version: $version\n"
            exit 0
            ;;
        "-w")
            shift
            await="$1" ;
            ;;
        "-b")
        # set to background
            await=60;
            count=0;
            ;;
        "-c")
            # loop count
            shift;
            count="$1"
            ;;
        "-x")
            # proxy
            shift;
#            args+=( $( echo "$1" | awk  -F":" '{ if ( $1 == "5" ) $1 = "socks5" ; if ( length($2) == 0 ) $2 = "//127.0.0.1" ; printf("-x %s:%s:%s",$1,$2,$3); }' ) )
#        args+=( $( echo "$1" | sed -n 's!\(.*:\)\?/*\(.*\):\(.*\)!\1,\2,\3!gp' | awk -F"," '{ $1=( length($1)==0 )?"http:"; $2=( length($2)==0 )?"127.0.0.1"; $1=( $1 ~ "5" )?"socks5:"; printf("-x %s//%s:%s\n",$1,$2,$3) }' ) )
        args+=( $( echo "$1" | awk -F':' 'function protof(a){ if ( length(a)==0 ) return "http"; return ( a ~ "5" )?"socks5":a; } function addr(b){ return ( length(b)==0 )?"127.0.0.1":b; } { if ( NF==3 ){ $1=protof($1); $2=addr($2); printf("-x %s://%s:%s\n",$1,$2,$3) } else { $1=addr($1); printf("-x http://%s:%s\n",$1,$2); }  }' ) )
            ;;
        "-A")
            # useragent
            shift;
            useragent="$1"
            ;;
        "-n"|"-n1")
            # NS check
            nstest=1
            ;;
        "-n2")
            # NS check
            nstest=2
            ;;
        "-n3")
            # NS check
            nstest=3
            ;;
        "-h")
            # help
            print_help
            exit 1
            ;;
        '-H')
            # curl header
            shift;
            curlhead+=( "$1" )
            ;;
        '-v')
            # show verbose
            show=1
            args+=( "-v" )
            ;;
        '-d')
            # assign dns server
            shift
            dns="$1"
            ;;
    '-r')
        # assign resolve ip
        shift
        resolve="$1"
        ;;
    '-ws')
        # web socket
        curlhead+=(  'Connection: close' 'Upgrade: websocket' 'Sec-WebSocket-Version: 13' )
        ;;
    '-wsk')
        # add Sec-WebSocket-Key
        curlhead+=( 'Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==' )
        ;;
        '-D' | '--dump-header')
            continue
            ;;
        '-o' | '--output')
            continue
            ;;
        '-s' | '--silent')
            continue
            ;;
        -*)
            args+=( "$1" )
            ;;
        *)
            filter="$( echo $1 | sed 's!^[Hh][Tt][Tt][Pp][Ss]*://!!;' )"
            hostname="${filter%%/*}"
            target+=( "$hostname" );
            uri="${filter##${hostname}}"
            [ "${uri}x" == "x" ] && uri="/"
            url+=( $uri );
#            echo "Target: $hostname"
#            echo "URI: $uri"
            ;;
    esac
    shift
done
#echo -e "ARGS: ${args[@]} , Curl Header: ${curlhead[@]} "
nstest=${nstest-0}
count=${count-1}
await=${await-1};
target=( ${target[@]-"apple.com"} )
simp=${simp-0}
show=${show-0}
resolve=${resolve-""}
[[ "${args[@]}" =~ "-v" ]] && args=( ${args[@]//-D-/} )
bodyout=${bodyout-/dev/null}
targetIP=();
nstracerip=();
function query(){
        if [ ${nstest} -gt 0 ] ; then
        	[ ${nstest} -le 2 ] && nscheck "$1"
        	[ ${nstest} -eq 3 ] && nscheck2 "$1"
        	echo -e "\n${BLUE}${1}:${NORMAL}" ;
        	echo -ne "${LIME_YELLOW}"
        	IP=( $(printf '%s\n' ${nstracerip[@]} | sort | uniq) )
        	echo -e "${IP[@]}"
        	echo -ne "${NORMAL}"
    else
        output="$(host $1 $dns 2>/dev/null)"
        echo -e "\n${BLUE}${1}:${NORMAL}\n$output" ;
	hostip=$(echo "$output" | awk '/has address/{print $(NF)}' | sort | uniq )
        if [ "$hostip" == "" ] ; then
            echo -e "${RED}Host no data${NORMAL}";
            targetIP+=( "" )
                        return
        else
            IP=( $hostip )
        fi
    fi
    targetIP+=( "${IP[*]}" )
    fdcount=10;
    ip138=()
    cip=()
    outian=()
    for ((d=0;d<${#IP[@]};d++)) ; do 
        eval 'exec '${fdcount}'< <( $CURL $CURLARG -m 10 "https://www.ip138.com/iplookup.asp?ip=${IP[$d]}&action=2" -A "$useragent" -s 2>/dev/null | iconv -c -f gb2312 -t utf-8 | awk -F'"'"'[,:{]'"'"' '"'"'/ip_result =/{ for(i=1;i<=NF;i++){ if ( $i ~ /ASN归属地|iP段|网友提交的IP|ct"|prov|city/ ){ data=data$(i+1) } } } END{ gsub(/""/,",",data); gsub(/"| /,"",data); print data }'"'"')'
        fdcount=$((fdcount+1))
        eval 'exec '${fdcount}'< <( $CURL $CURLARG -m 10 "http://cip.cc/${IP[$d]}" -s 2>/dev/null | awk -F":" '"'"'NR>1 && NR<7 && $2 != "" { $1="" ; gsub(/ +/,"",$0); gsub(/\|/,"",$0); printf("%s,",$0); }'"'"' )' 
        fdcount=$((fdcount+1))
    done
    eval 'exec '${fdcount}'< <( $CURL $CURLARG -d "list=$( echo ${IP[@]}| sed '"'"'s/ /%0D%0A/g'"'"' )&submit=Submit" "outian.org/ip2cy.php" | awk '"'"'/<td|<tr/{ if ( $0 ~ /Input|IP|DN|Country|City/ ) next; else if ( $0 ~ /<tr|nbsp/ ){ $0="\n" }; gsub("<td>","",$0); gsub("</td>",",",$0); printf("%s",$0); }'"'"' )'
    fdcount=10;
    for ((d=0;d<${#IP[@]};d++)); do 
        ip138[$d]="$(cat <&${fdcount})"
        eval 'exec '${fdcount}'<&-'
        fdcount=$((fdcount+1))
        cip[$d]="$( cat <&${fdcount})"
        eval 'exec '${fdcount}'<&-'
        fdcount=$((fdcount+1))
    done
    d=0;
    IFS=$'\n'
    for x in $( cat <&${fdcount} ); do
        outian[$d]="$x"
        d=$((d+1))
    done
    eval 'exec '${fdcount}'<&-'
    IFS=$' \t\n'
    echo -e "${NORMAL}======================================================="
    for ((d=0;d<${#IP[@]};d++)); do 
        printf "IP: ${RED}%-15s ${BLUE}%-6s: ${YELLOW}%s${NORMAL}\n" "${IP[$d]}" "ip138" "${ip138[$d]}"
        printf "IP: ${RED}%-15s ${BLUE}%-6s: ${YELLOW}%s${NORMAL}\n" "${IP[$d]}" "cip" "${cip[$d]}"
        printf "IP: ${RED}%-15s ${BLUE}%-6s: ${YELLOW}%s${NORMAL}\n" "${IP[$d]}" "outian" "${outian[$d]}"
        echo -e "${NORMAL}======================================================="
     done

# 使用 jq 為範本，但因非預設安裝，所以放棄    
#    while read key value ; do myarray[$key]="$value" ; done < <( $CURL $CURLARG -m 10  "https://www.ip138.com/iplookup.asp?ip=${x}&action=2" -A "$useragent" 2>/dev/null | iconv -c -f gb2312 -t utf-8 | sed -n '/ip_result =/{s/^.* \({.*}\);.*$/\1/; s/[[:space:]]//gp; }; ' | jq -r 'to_entries|map( "\(.key) \(.value|tostring)")|.[]' ) 
#    printf "${RED}%-15s ${BLUE}%-5s ${YELLOW}%s\n" "$x" "ip138" "${myarray[ASN归属地]},${myarray[iP段]},${myarray[网友提交的IP]}" 
#    curl -s -d "list=8.8.8.8%0D%0A211.21.65.250&submit=Submit" "outian.org/ip2cy.php" | awk '/<td>/{ if ( $0 ~ /Input|IP|DN|Country|City/ ) next; else if ( $0 ~ /nbsp/ ){ $0="\n" }; gsub("<td>","",$0); gsub("</td>",",",$0);  printf("%s",$0); }
#    for x in ${IP[@]}; do
#        $CURL $CURLARG -m 10 "https://www.ip138.com/iplookup.asp?ip=${x}&action=2" -A "$useragent" -s 2>/dev/null | iconv -c -f gb2312 -t utf-8 | awk -F'[,:{]' '/ip_result =/{ for(i=1;i<=NF;i++){ if ( $i ~ /ASN归属地|iP段|网友提交的IP|ct"|prov|city/ ){ data=data$(i+1) } } } END{ gsub(/""/,",",data); gsub(/"| /,"",data); printf("IP: '${RED}'%-15s '${BLUE}'%-5s: '${YELLOW}'%s'${NORMAL}'\n","'${x}'","ip138",data); }' &
#        $CURL $CURLARG -m 10 "http://cip.cc/$x" -s 2>/dev/null | awk -F":" 'BEGIN{ printf("    '${RED}'%-15s '${BLUE}'%-5s: '${YELLOW}'","'${x}'","cip" ); } NR>1 && NR<7 && $2 != "" { $1="" ; gsub(/ +/,"",$0); gsub(/\|/,"",$0); printf("%s,",$0); } END{ print "'${NORMAL}'" }' &
#        wait < <(jobs -p)
#        echo -e "${NORMAL}======================================================="
#    done
}

function main(){
    array=( ${1//:/ } )
    ip=( ${3//#/ } )
    data1=()
    data2=()
    echo -e "Target: ${RED}$1${NORMAL}\t$(date)" 
    # depoly multi-thread curl
    fdcount=10
    for ((c=0;c<${#ip[@]};c++)) ; do
        eval 'exec '${fdcount}'< <( $CURL $CURLARG ${args[@]} "${curlhead[@]/#/-H}" -w "$curl_format" -A "$useragent"  -o $bodyout -H "Origin: https://${1}${2}" --resolve "${array[0]}:${array[1]-443}:${ip[$c]}" "https://${1}${2}" 2>&1 );'
        fdcount=$((fdcount+1))
        eval 'exec '${fdcount}'< <( $CURL $CURLARG ${args[@]} "${curlhead[@]/#/-H}" -w "$curl_format" -A "$useragent"  -o $bodyout -H "Origin: http://${1}${2}" --resolve "${array[0]}:${array[1]-80}:${ip[$c]}" "http://${1}${2}" 2>&1 );'
        fdcount=$((fdcount+1))
    done; 
    # run multi-thread curl and close fd, result to array
    fdcount=10
    for ((c=0;c<${#ip[@]};c++)) ; do
        data1+=( "$(cat <&${fdcount} ),${ip[$c]},${array[1]-443}" )
        eval 'exec '$fdcount'<&-'
        fdcount=$((fdcount+1))
        data2+=( "$(cat <&${fdcount} ),${ip[$c]},${array[1]-80}" )
        eval 'exec '$fdcount'<&-'
        fdcount=$((fdcount+1))
    done
    for ((c=0;c<${#ip[@]};c++)); do 
        if [ $show -eq 1 ] ; then
            echo -e "${NORMAL}========== https / ${RED}${ip[$c]}:${array[1]-443}${NORMAL} ==========";  
            echo "${data1[c]}%$'\n'*}" | sed -n '$d; 1,$p' | awk -F": " '/^(\* About|< |HTTP)/,/^<?[[:space:]]*$/{ if ( NF > 1 ){ printf("'${WHITE}'%-s:",$1); $1=""; printf("'${CYAN}'%-s'${NORMAL}'\n",$0) } else printf("'${GREEN}'%-s'${NORMAL}'\n",$0); } /^<[^ ]/,G{ print $0 }' 
            echo -e "${NORMAL}========== http / ${RED}${ip[$c]}:${array[1]-80 }${NORMAL} =========="; 
            echo "${data2[c]}%$'\n'*}" | sed -n '$d; 1,$p' | awk -F": " '/^(\* About|< |HTTP)/,/^<?[[:space:]]*$/{ if ( NF > 1 ){ printf("'${WHITE}'%-s:",$1); $1=""; printf("'${CYAN}'%-s'${NORMAL}'\n",$0) } else printf("'${GREEN}'%-s'${NORMAL}'\n",$0); } /^<[^ ]/,G{ print $0 }' 
        fi
    done
    printf "${RED}%-5s ${GREEN}%-21s ${YELLOW}%-4s ${LIME_YELLOW}%-8s${POWDER_BLUE}%-8s${BLUE}%-8s${MAGENTA}%-8s${CYAN}%-8s${WHITE}%-8s${BRIGHT}%-8s${NORMAL}\n" "Proto" "  IP+Port" "Code" "DNS" "Conn" "SSL" "Server" "Transfe" "Total" "Download"
    for((c=0;c<${#ip[@]};c++));do
        echo "${data1[$c]##*$'\n'}" | awk 'BEGIN{FS=","} { printf("'${RED}'https '${GREEN}'%15s:%-5s '${YELLOW}'%-4s '${LIME_YELLOW}'%-'\''7d '${POWDER_BLUE}'%-'\''7d '${BLUE}'%-'\''7d '${MAGENTA}'%-'\''7d '${CYAN}'%-'\''7d '${WHITE}'%-'\''7d '${BRIGHT}'%d'${NORMAL}'\n",$10,$11,$9,$1*1000,($2-$1)*1000,($4-$2)*1000,($6-$4)*1000,($7-$6)*1000,$7*1000,$8) }';
        echo "${data2[$c]##*$'\n'}" | awk 'BEGIN{FS=","} { printf("'${RED}'http  '${GREEN}'%15s:%-5s '${YELLOW}'%-4s '${LIME_YELLOW}'%-'\''7d '${POWDER_BLUE}'%-'\''7d '${BLUE}'%7s '${MAGENTA}'%-'\''7d '${CYAN}'%-'\''7d '${WHITE}'%-'\''7d '${BRIGHT}'%d'${NORMAL}'\n",$10,$11,$9,$1*1000,($2-$1)*1000,"",($6-$4)*1000,($7-$6)*1000,$7*1000,$8) }';  
    done
}
function main2(){
    echo -e "Target: ${RED}$1${NORMAL}\t$(date)" 
    exec 10< <( $CURL $CURLARG ${args[@]} "${curlhead[@]/#/-H}" -w "$curl_format2" -A "$useragent" -o $bodyout -H "Origin: https://${1}${2}" "https://${1}${2}" 2>&1 ) 
    exec 11< <( $CURL $CURLARG ${args[@]} "${curlhead[@]/#/-H}" -w "$curl_format2" -A "$useragent" -o $bodyout -H "Origin: http://${1}${2}" "http://${1}${2}"  2>&1 )
    data1="$( cat <&10 )"; exec 10<&-
    data2="$( cat <&11 )"; exec 11<&-
    if [ $show -eq 1 ] ; then
        echo -e "${NORMAL}========== https / ${RED}${1}${NORMAL} ==========";  
        echo "${data1%$'\n'*}" | sed -n '$d; 1,$p' | awk -F": " '/^(\* About|< |HTTP)/,/^<?[[:space:]]*$/{ if ( NF > 1 ){ printf("'${WHITE}'%-s:",$1); $1=""; printf("'${CYAN}'%-s'${NORMAL}'\n",$0) } else printf("'${GREEN}'%-s'${NORMAL}'\n",$0); } /^<[^ ]/,G{ print $0 }' 
        echo "${NORMAL}========== http / ${RED}${1}${NORMAL} =========="; 
        echo "${data2%$'\n'*}" | sed -n '$d; 1,$p' | awk -F": " '/^(\* About|< |HTTP)/,/^<?[[:space:]]*$/{ if ( NF > 1 ){ printf("'${WHITE}'%-s:",$1); $1=""; printf("'${CYAN}'%-s'${NORMAL}'\n",$0) } else printf("'${GREEN}'%-s'${NORMAL}'\n",$0); } /^<[^ ]/,G{ print $0 }' 
    fi
    printf "${RED}%-5s ${GREEN}%-21s ${YELLOW}%-4s ${LIME_YELLOW}%-8s${POWDER_BLUE}%-8s${BLUE}%-8s${MAGENTA}%-8s${CYAN}%-8s${WHITE}%-8s${BRIGHT}%-8s${NORMAL}\n" "Proto" "  IP+Port" "Code" "DNS" "Conn" "SSL" "Server" "Transfe" "Total" "Download"
    echo "${data1##*$'\n'}" | awk 'BEGIN{FS=","} { printf("'${RED}'https '${GREEN}'%15s:%-5s '${YELLOW}'%-4s '${LIME_YELLOW}'%-'\''7d '${POWDER_BLUE}'%-'\''7d '${BLUE}'%-'\''7d '${MAGENTA}'%-'\''7d '${CYAN}'%-'\''7d '${WHITE}'%-'\''7d '${BRIGHT}'%d'${NORMAL}'\n",$10,$11,$9,$1*1000,($2-$1)*1000,($4-$2)*1000,($6-$4)*1000,($7-$6)*1000,$7*1000,$8) }';
    echo "${data2##*$'\n'}" | awk 'BEGIN{FS=","} { printf("'${RED}'http  '${GREEN}'%15s:%-5s '${YELLOW}'%-4s '${LIME_YELLOW}'%-'\''7d '${POWDER_BLUE}'%-'\''7d '${BLUE}'%7s '${MAGENTA}'%-'\''7d '${CYAN}'%-'\''7d '${WHITE}'%-'\''7d '${BRIGHT}'%d'${NORMAL}'\n",$10,$11,$9,$1*1000,($2-$1)*1000,"",($6-$4)*1000,($7-$6)*1000,$7*1000,$8) }';  
}
function nscheck2(){
        echo "Check $1 NS server"
	dns=${dns-"$(grep -m1  "nameserver" /etc/resolv.conf | cut -d" " -f2)"}
    nssoutput="$( dig +noall +answer @${dns} $1 | awk '{ printf("%s,%s,%s,%s\n",$1,$2,$4,$5);}' )"
    for x in $(printf "%s\n" $nssoutput); do
	IFS=',' read -ra dig_A <<< "$x"
        if [ "${dig_A[2]}" == "A" ] ; then 
		echo -e "${dig_A[0]}\t==> ${dig_A[2]}\t${dig_A[1]}\t${dig_A[3]}"
		nstracerip+=( ${dig_A[3]} );
        elif [ "${dig_A[2]}" == "CNAME" ] ; then 
		echo -e "${dig_A[0]}\t==> ${dig_A[2]}\t${dig_A[1]}\t${dig_A[3]}"
        fi
        done
}

function nscheck(){
    if [ $nstest -eq 1 ] ; then
        sufix="${1##*.}"
        if [ "$sufix" == "net" ] || [ "$sufix" == "com" ] ; then
            dns="b.gtld-servers.net";
        elif [ "$sufix" == "cn" ] ; then
            dns="a.dns.cn";
        elif [ "$sufix" == "tw" ] ; then
            dns="a.dns.tw";
        else
	    dns=${dns-"$( awk '/^nameserver/{ print $2 }' /etc/resolv.conf | sort | uniq | head -n1 )"}
        fi
    else
        dns=${dns-"$( awk '/^nameserver/{ print $2 }' /etc/resolv.conf | sort | uniq | head -n1 )"}
    fi
    nssoutput="$(dnstracer -4 -o -t 3 -r 1 -s $dns $1)";
    echo "$nssoutput";
    for x in $(echo "${nssoutput}" | awk '/^$/,G{ if ( $1 ) print $5}'|sort|uniq)
        do if [ "$( echo $x | grep -E -o '([0-9]{1,3}[\.]){3}[0-9]{1,3}' )" == "" ] ; then
            nscheck "$x" ;
        else
    	    nstracerip+=( "$x" )
        fi
    done
}

for((i=0;i<${#target[@]};i++)); do
    if [ "${resolve}x" == "x" ] ; then
        query "${target[$i]%:*}" 
    else
        targetIP+=( "${resolve}" )
    fi
done
j=0
while [ "$count" -eq 0 ] || [ "$j" -lt "$count" ] ; do
    for((i=0;i<${#target[@]};i++)); do
        if [ "$simp" -eq 1 ] ; then
            main2 "${target[$i]}" "${url[$i]}" 
        else
            if [ ${#targetIP[$i]} -gt 0 ]; then
                                main "${target[$i]}" "${url[$i]}" "${targetIP[$i]}"
                        fi
        fi
    done
    j=$((j+1))
    sleep $await;
done
