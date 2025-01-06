#!/bin/bash
version='0.2.33'
#useragent=${useragent-"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"}
#useragent=${useragent-"Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1"}
#useragent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.71 Safari/537.36 Edg/97.0.1072.55"
useragent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36"
CURLARG='--connect-timeout 10 --max-time 15 -s --compressed'
curl_format='\n%{time_namelookup},%{time_connect},%{time_appconnect},%{time_pretransfer},%{time_redirect},%{time_starttransfer},%{time_total},%{size_download},%{speed_download},%{http_code}'
curl_format2='\n%{time_namelookup},%{time_connect},%{time_appconnect},%{time_pretransfer},%{time_redirect},%{time_starttransfer},%{time_total},%{size_download},%{speed_download},%{http_code},%{remote_ip},%{remote_port}'
# 顏色色碼列表, https://en.wikipedia.org/wiki/ANSI_escape_code
# for c in {0..255}; do tput setaf $c; tput setaf $c | cat -v; echo -n "=$c "; done
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
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)
NORMAL=$(tput sgr0)
Color201=$(tput setaf 201)
resolve=()
curlhead=()
onlyhttp=0
onlyhttps=0
args=()
ChangeLog="
0.2.15: fix error in host command reset connect
0.2.16: Modify exit to return after host get empty data
0.2.17: Modify dig format
    Add -n1 , -n2 , dig +trace
0.2.18: fix http header display bug
0.2.19: add -1(showhead), -2(showbody), fix hostname bug, fix showhead and -v bug
0.2.20: fix curl version check bug
0.2.21: add/modify TTFB time
0.2.22: fix ipme syntax error in macos
    fix query flood, add interval 0.3sec between curl
0.2.23: fix proxy syntax
0.2.24: tune http header color in 2023.11.03
0.2.25: tune curl write out format color in 2023.11.04
0.2.26: support query IPv4 in 2023.11.07
0.2.27: tune work flow in 2023.11.08
0.2.28: add -http & -https for only detect http,https in 2023.11.9
0.2.29: fine tune dnstracer to variable same time output in 2023.11.10
0.2.30: fine tune in 2023.11.10
0.2.31: tune nscheck function in 2023.11.13
0.2.32: change default web site to www.apple.com
0.2.33: add -qnv
"

[ -f /usr/local/bin/curl ] && CURL=/usr/local/bin/curl
CURL=${CURL-/usr/bin/curl}
curlversion=$( $CURL --version | awk '/^curl/{ print $2 }' | sed 's/\(.*\)\./\1/')
if (( $( echo "$curlversion < 7.214" | bc ) )) ; then
	echo "Please Upgrade curl version >= 7.21.3"
	exit 1;
fi
print_help(){
    cat <<EOF
$0 [OPTIONS] [ curl options args ] [target site]
	[target site]    Target site domain name,default www.apple.com
Version: $version

OPTIONS:
	-b		Default Interval 60s, Unlimit running
	-h		this help
	-n|-n1		dnstracer 快速查詢(快, 但會有查不出結果的問題, 如果 IP 為空值，請用 -n2 代替)
	-n2		使用 dig +tracer (較快, 但無法確認 name server 是否正常)
	-v		curl -v 相等，不建議再開 -showhead
	-simp		curl 只有針對域名測試，
			不會單獨測試每個 IP,
			會有正確的 curl dns 查詢時間
	-showhead or -1	dump http repone header
	-showbody or -2	show http body
	-http		only http detect
	-https		only https detect
	-version	show version
	-ws		WebSocket protocol
	-wsk		Added header Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==
	-w [sec]	interval, default 1s
	-c [num]	loop count,default 1,0 =  keep run
	-q		查詢 IP 歸屬地
	-qnv		快速指定 -q -n -v
	-dns [DnsIp]	指定 dns server
	-A [useragent]	UserAgent UserAgent
	-x [ proxy ]	Proxy Server,可以用 5::1086 or 5:127.0.0.1:1086 替代 socks5://127.0.0.1:1086
			註: socks5 才有支援查詢 dns 回應的每個個 IP
	-r [ ip ]	指定 ip
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
		echo -e "${ChangeLog}\n\n"
		exit 0
		;;
	"-w")
		shift
		await="$1" ;
		;;
	"-b")
		# set to sleep default 60sec unlimit count
		await=${await-60};
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
		args+=( $( echo "$1" | awk -F':' 'function protof(a){ if ( length(a)==0 ) return "http"; return ( a ~ "5" )?"socks5":a; } function addr(b){ return ( length(b)==0 )?"127.0.0.1":b; } { if ( NF==3 ){ $1=protof($1); gsub(/\/\//,"",$2); $2=addr($2); printf("-x %s://%s:%s\n",$1,$2,$3) } else { $1=addr($1); printf("-x http://%s:%s\n",$1,$2); }  }' ) )
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
	'-d')
		# post data
		shift;
		args+=( "-d $1" )
		;;
	'-v')
		# show verbose
		show=1
		args+=( "-v" )
		;;
	'-dns')
		# assign dns server
		shift
		dns="$1"
		;;
	'-r')
		# assign resolve ip
		shift
		resolve+=( "$1" )
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
		show=1
		args+=( "-D-" )
		;;
	'-q')
		# query ip location
		querymap=1
		;;
	'-qnv')
		querymap=1
		nstest=1
		show=1
		args+=( "-v" )
		;;	
	'-http')
		onlyhttp=1
		;;
	'-https')
		onlyhttps=1
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
		filter="$( echo $1 | sed 's!^http[s]\?://!!i;' )"
		hostname="${filter%%/*}"
		#target+=( "${hostname,,}"  ); #for bash 4.0 above
		target+=( "$( tr '[A-Z]' '[a-z]' <<< $hostname)"  );
		uri="${filter##${hostname}}"
		[ "${uri}x" == "x" ] && uri="/"
		url+=( $uri );
		;;
	esac
	shift
done
#echo -e "ARGS: ${args[@]} , Curl Header: ${curlhead[@]} "
nstest=${nstest-0}
count=${count-1}
await=${await-10};
target=( ${target[@]-"www.apple.com"} )
simp=${simp-0}
show=${show-0}
querymap=${querymap-0}
[[ "${args[@]}" =~ "-v" ]] && args=( ${args[@]//-D-/} )
bodyout=${bodyout-/dev/null}
targetIP=();
function queryip(){
	local IP=()
	local nstracerip=();
	if [ ${nstest} -gt 0 ] ; then
		[ ${nstest} -le 1 ] && nscheck "$1"
		[ ${nstest} -eq 2 ] && nscheck2 "$1"
		IP=( $(printf '%s\n' ${nstracerip[@]} | sort | uniq) )
	else
		[ "." == "${dns}" ] && dns=""
		IP=( $(host $1 $dns 2>/dev/null  | awk '/has address/{print $(NF)}' | sort | uniq ) )
		[ "${IP[0]}x" == "x" ] && echo -e "${RED}Host no IP address!${NORMAL}";
	fi
	echo -e "\n${BLUE}${1}:\tTotal IPs: ${#IP[*]}\n${LIME_YELLOW}${IP[*]}${NORMAL}" ;
	targetIP+=( "${IP[*]}" )
	[[ ${querymap} -eq 1 ]] && queryipmap "${IP[*]}"	
}
function queryipmap(){
	local IP=( ${1} )
	local fdcount=10;
	#ip138=()
	local ipme=()
#	local cip=()
	local ipinfo=()
	local outian=()
	for ((d=0;d<${#IP[@]};d++)) ; do
       		#eval 'exec '${fdcount}'< <( $CURL $CURLARG -m 10 "https://www.ip138.com/iplookup.asp?ip=${IP[$d]}&action=2" -A "$useragent" -s 2>/dev/null | iconv -c -f gb2312 -t utf-8 | awk -F'"'"'[,:{]'"'"' '"'"'/ip_result =/{ for(i=1;i<=NF;i++){ if ( $i ~ /ASN归属地|iP段|网友提交的IP|ct"|prov|city/ ){ data=data$(i+1) } } } END{ gsub(/""/,",",data); gsub(/"| /,"",data); print data }'"'"')'
		#eval 'exec '${fdcount}'< <( $CURL $CURLARG -m 10 "https://ip.me/${IP[$d]}" -s 2>/dev/null | sed -n "s!.*<\(th\|code\)>\(.*\)</\(th\|code\)>.*!\2!gp;" | awk '"'"'(NR==2||NR==4||NR==6||NR==14||NR==18){ printf $0"," }'"'"' )'
		eval 'exec '${fdcount}'< <( $CURL $CURLARG -m 10 "https://ip.me/${IP[$d]}" -s 2>/dev/null | sed -nE "s!.*<(th|code)>(.*)</(th|code)>.*!\2!p" | awk '"'"'(NR==2||NR==4||NR==6||NR==14||NR==18){ printf $0"," }'"'"' )'
		fdcount=$((fdcount+1))
#		eval 'exec '${fdcount}'< <( $CURL $CURLARG -m 10 "http://cip.cc/${IP[$d]}" -s 2>/dev/null | awk -F":" '"'"'NR>1 && NR<7 && $2 != "" { $1="" ; gsub(/ +/,"",$0); gsub(/\|/,"",$0); printf("%s,",$0); }'"'"' )'
		eval 'exec '${fdcount}'< <( $CURL $CURLARG -m 10 "http://ipinfo.io/${IP[$d]}" -s 2>/dev/null | awk -F'"'"'"'"'"' '"'"'{ if ( $2 ~ /hostname|city|region|country/ ) printf("%s,",$4); else if ( $2 ~ /org/ ) printf("%s\n",$4); }'"'"' )'
		fdcount=$((fdcount+1))
		ping -i 0.2 -c 2 127.0.0.1 >/dev/null
	done
	eval 'exec '${fdcount}'< <( $CURL $CURLARG -d "list=$( echo ${IP[@]}| sed '"'"'s/ /%0D%0A/g'"'"' )&submit=Submit" "outian.org/ip2cy.php" | awk '"'"'/<td|<tr/{ if ( $0 ~ /Input|IP|DN|Country|City/ ) next; else if ( $0 ~ /<tr|nbsp/ ){ $0="\n" }; gsub("<td>","",$0); gsub("</td>",",",$0); printf("%s",$0); }'"'"' )'
	fdcount=10;
	for ((d=0;d<${#IP[@]};d++)); do
		ipme[$d]="$(cat <&${fdcount})"
		eval 'exec '${fdcount}'<&-'
		fdcount=$((fdcount+1))
#		cip[$d]="$( cat <&${fdcount})"
		ipinfo[$d]="$( cat <&${fdcount})"
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
		printf "IP: ${RED}%-15s ${BLUE}%-6s: ${YELLOW}%s${NORMAL}\n" "${IP[$d]}" "ipme" "${ipme[$d]}"
#		printf "IP: ${RED}%-15s ${BLUE}%-6s: ${YELLOW}%s${NORMAL}\n" "${IP[$d]}" "cip" "${cip[$d]}"
		printf "IP: ${RED}%-15s ${BLUE}%-6s: ${YELLOW}%s${NORMAL}\n" "${IP[$d]}" "ipinfo" "${ipinfo[$d]}"
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
	domain=( ${1/:/ } )
	ip=( ${3} )
	data1=()
	data2=()
	echo -e "Target: ${RED}$1${NORMAL}\t$(date)"
	# depoly multi-thread curl
	fdcount=10
	for ((c=0;c<${#ip[@]};c++)) ; do
		[ ${onlyhttp} -eq 0 ] && eval 'exec '${fdcount}'< <( $CURL $CURLARG ${args[@]} "${curlhead[@]/#/-H}" -w "$curl_format" -A "$useragent"  -o $bodyout -H "Origin: https://${1}${2}" --resolve "${domain[0]}:${domain[1]-443}:${ip[$c]}" "https://${1}${2}" 2>&1 );'
		fdcount=$((fdcount+1))
		[ ${onlyhttps} -eq 0 ] && eval 'exec '${fdcount}'< <( $CURL $CURLARG ${args[@]} "${curlhead[@]/#/-H}" -w "$curl_format" -A "$useragent"  -o $bodyout -H "Origin: http://${1}${2}" --resolve "${domain[0]}:${domain[1]-80}:${ip[$c]}" "http://${1}${2}" 2>&1 );'
		fdcount=$((fdcount+1))
		sleep 0.2
	done;
	# run multi-thread curl and close fd, result to array
	fdcount=10
	for ((c=0;c<${#ip[@]};c++)) ; do
       		[ ${onlyhttp} -eq 0 ] && data1+=( "$(cat <&${fdcount} ),${ip[$c]},${domain[1]-443}" ) && eval 'exec '$fdcount'<&-'
		fdcount=$((fdcount+1))
		[ ${onlyhttps} -eq 0 ] && data2+=( "$(cat <&${fdcount} ),${ip[$c]},${domain[1]-80}" ) && eval 'exec '$fdcount'<&-'
		fdcount=$((fdcount+1))
	done
	for ((c=0;c<${#ip[@]};c++)); do
		if [ $show -eq 1 ] ; then
			if [ ${onlyhttp} -eq 0 ] ; then
				echo -e "${NORMAL}========== https / ${RED}${ip[$c]}:${domain[1]-443}${NORMAL} ==========";
				#echo "${data1[c]}%$'\n'*}" | sed -n '$d; 1,$p' |  awk 'BEGIN{FS=",:"} {if ( $0 ~ /\r$/ ){ if ($0 ~ /:/){ split($0,str,/:/); printf("'${YELLOW}'%-s: '${CYAN}'%-s'${NORMAL}'\n",str[1],str[2])} else printf("'${RED}'%-s'${NORMAL}'\n",$0) } else if ( $0 ~ /^\* / ){ printf("'${POWDER_BLUE}'%-s'${NORMAL}'\n",$0); }  else printf("'${GREEN}'%-s'${NORMAL}'\n",$0) }'
				#echo "${data1[c]}%$'\n'*}" | sed -n '$d; 1,$p' |  awk '{if ( $0 ~ /\r$/ ){ if ($0 ~ /:/){ if ( length($1)==1 ){ str=$1" "$2; $1="";$2=""} else { str=$1; $1="" } printf("'${YELLOW}'%s'${CYAN}'%s\n",str,$0); } else printf("'${RED}'%s\n",$0) } else if ( $0 ~ /^\* / ){ printf("'${POWDER_BLUE}'%s\n",$0); } else printf("'${GREEN}'%s\n",$0) } END{ printf "'${NORMAL}'" }'
				echo "${data1[c]}%$'\n'*}" | sed -n '$d; 1,$p' |  awk '{if ( $0 ~ /\r$/ ){ if ($0 ~ /: /){  FS=": "; $0=$0; str=$1; $1=""; printf("'${YELLOW}'%s:'${CYAN}'%s\n",str,$0); } else printf("'${RED}'%s\n",$0) } else if ( $0 ~ /^\* / ){ printf("'${POWDER_BLUE}'%s\n",$0); } else printf("'${GREEN}'%s\n",$0) } END{ printf "'${NORMAL}'" }'

			fi
			if [ ${onlyhttps} -eq 0 ] ; then
				echo -e "${NORMAL}========== http / ${RED}${ip[$c]}:${domain[1]-80 }${NORMAL} ==========";
				echo "${data2[c]}%$'\n'*}" | sed -n '$d; 1,$p' |    awk '{if ( $0 ~ /\r$/ ){ if ($0 ~ /: /){  FS=": "; $0=$0; str=$1; $1=""; printf("'${YELLOW}'%s:'${CYAN}'%s\n",str,$0); } else printf("'${RED}'%s\n",$0) } else if ( $0 ~ /^\* / ){ printf("'${POWDER_BLUE}'%s\n",$0); } else printf("'${GREEN}'%s\n",$0) } END{ printf "'${NORMAL}'" }'
			fi
		fi
	done
	printf "${RED}%-5s ${GREEN}%-21s ${YELLOW}%4s ${POWDER_BLUE}%6s ${BLUE}%6s ${MAGENTA}%6s ${CYAN}%6s ${LIME_YELLOW}%9s ${WHITE}%-10s${NORMAL}\n" "Proto" "  IP+Port" "Code" "Conn" "SSL" "TTFB" "Total" "ByteSize" "Download/s"
	for((c=0;c<${#ip[@]};c++));do
		[ ${onlyhttp} -eq 0 ] && echo "${data1[$c]##*$'\n'}" | awk 'function aaa(x,y){ return x == 0 ? 0 : (x-y)*1000 } BEGIN{FS=","} { printf("'${RED}'https '${GREEN}'%15s:%-5s '${YELLOW}'%4s '${POWDER_BLUE}'%'\''6d '${BLUE}'%'\''6d '${MAGENTA}'%'\''6d '${CYAN}'%'\''6d '${LIME_YELLOW}'%'\''9d '${WHITE}'%'\''9.2fk'${NORMAL}'\n",$11,$12,$10,aaa($2,$1),aaa($3,$2),aaa($6,$3),$7*1000,$8,$9/1000) }';
		[ ${onlyhttps} -eq 0 ] && echo "${data2[$c]##*$'\n'}" | awk 'function aaa(x,y){ return x == 0 ? 0 : (x-y)*1000 } BEGIN{FS=","} { printf("'${RED}'http  '${GREEN}'%15s:%-5s '${YELLOW}'%4s '${POWDER_BLUE}'%'\''6d '${BLUE}'%'\''6s '${MAGENTA}'%'\''6d '${CYAN}'%'\''6d '${LIME_YELLOW}'%'\''9d '${WHITE}'%9.2fk'${NORMAL}'\n",$11,$12,$10,aaa($2,$1),"",aaa($6,$2),$7*1000,$8,$9/1000) }';
	done
}
function main2(){
	echo -e "Target: ${RED}$1${NORMAL}\t$(date)"
	[ ${onlyhttp} -eq 0 ] && exec 10< <( $CURL $CURLARG ${args[@]} "${curlhead[@]/#/-H}" -w "$curl_format2" -A "$useragent" -o $bodyout -H "Origin: https://${1}${2}" "https://${1}${2}" 2>&1 )
	[ ${onlyhttps} -eq 0 ] && exec 11< <( $CURL $CURLARG ${args[@]} "${curlhead[@]/#/-H}" -w "$curl_format2" -A "$useragent" -o $bodyout -H "Origin: http://${1}${2}" "http://${1}${2}"  2>&1 )
	[ ${onlyhttp} -eq 0 ] && data1="$( cat <&10 )" && exec 10<&-
	[ ${onlyhttps} -eq 0 ] && data2="$( cat <&11 )" && exec 11<&-
	if [ $show -eq 1 ] ; then
		if [ ${onlyhttp} -eq 0 ] ; then
			echo -e "${NORMAL}========== https / ${RED}${1}${NORMAL} ==========";
			echo "${data1%$'\n'*}" | sed -n '$d; 1,$p' | awk '{if ( $0 ~ /\r$/ ){ if ($0 ~ /: /){  FS=": "; $0=$0; str=$1; $1=""; printf("'${YELLOW}'%s:'${CYAN}'%s\n",str,$0); } else printf("'${RED}'%s\n",$0) } else if ( $0 ~ /^\* / ){ printf("'${POWDER_BLUE}'%s\n",$0); } else printf("'${GREEN}'%s\n",$0) } END{ printf "'${NORMAL}'" }'
		fi
		if [ ${onlyhttps} -eq 0 ] ; then
			echo "${NORMAL}========== http / ${RED}${1}${NORMAL} ==========";
			echo "${data2%$'\n'*}" | sed -n '$d; 1,$p' | awk '{if ( $0 ~ /\r$/ ){ if ($0 ~ /: /){  FS=": "; $0=$0; str=$1; $1=""; printf("'${YELLOW}'%s:'${CYAN}'%s\n",str,$0); } else printf("'${RED}'%s\n",$0) } else if ( $0 ~ /^\* / ){ printf("'${POWDER_BLUE}'%s\n",$0); } else printf("'${GREEN}'%s\n",$0) } END{ printf "'${NORMAL}'" }'
		fi
	fi
	printf "${RED}%-5s ${GREEN}%-21s ${YELLOW}%4s ${Color201}%6s ${POWDER_BLUE}%6s ${BLUE}%6s ${MAGENTA}%6s ${CYAN}%6s ${LIME_YELLOW}%9s ${WHITE}%-10s${NORMAL}\n" "Proto" "  IP+Port" "Code" "DNS" "Conn" "SSL" "TTFB" "Total" "ByteSize" "Download/s" 
	[ ${onlyhttp} -eq 0 ] && echo "${data1##*$'\n'}" | awk 'function aaa(x,y){ return x == 0 ? 0 : (x-y)*1000 } BEGIN{FS=","} { printf("'${RED}'https '${GREEN}'%15s:%-5s '${YELLOW}'%4s '${Color201}'%'\''6d '${POWDER_BLUE}'%'\''6d '${BLUE}'%'\''6d '${MAGENTA}'%'\''6d '${CYAN}'%'\''6d '${LIME_YELLOW}'%'\''9d '${WHITE}'%'\''9.2fk'${NORMAL}'\n",$11,$12,$10,$1*1000,aaa($2,$1),aaa($3,$2),aaa($6,$3),$7*1000,$8,$9/1000) }';
	[ ${onlyhttps} -eq 0 ] && echo "${data2##*$'\n'}" | awk 'function aaa(x,y){ return x == 0 ? 0 : (x-y)*1000 } BEGIN{FS=","} { printf("'${RED}'http  '${GREEN}'%15s:%-5s '${YELLOW}'%4s '${Color201}'%'\''6d '${POWDER_BLUE}'%'\''6d '${BLUE}'%'\''6s '${MAGENTA}'%'\''6d '${CYAN}'%'\''6d '${LIME_YELLOW}'%'\''9d '${WHITE}'%9.2fk'${NORMAL}'\n",$11,$12,$10,$1*1000,aaa($2,$1),"",aaa($6,$2),$7*1000,$8,$9/1000) }';
}
function nscheck2(){
	#local nssoutput=""
	[ "${dns}x" == "x" -o "${dns}" == "." ] && dns="" || dns="${dns/#/@}"
	echo "Check $1 NS server => ${dns}"
	while read w x y z ; do
		echo -e "${w}\t${y} ==> ${x}\t${z}"
		[[ "A" == "${y}" ]] && nstracerip+=( "${z}" ) 
        done < <( dig +noall +answer ${dns} $1 2>/dev/null | awk '$4=="A"||$4=="CNAME"{ print $1,$2,$4,$5}' )
}

function nscheck(){
	sufix="${1##*.}"
	#dns=${dns-"$(awk '$1=="nameserver" {print $2; exit }' /etc/resolv.conf)"}
	local triger=0
	local cname=()		
	local ldns=""
	if [ "${dns}x" == "x" -o "${dns}" == "." ] ; then
		if [[ $sufix =~ com|net ]] ; then
			ldns="a.gtld-servers.net";
		elif [ "$sufix" == "cn" ] ; then
			ldns="a.dns.cn";
		elif [ "$sufix" == "tw" ] ; then
			ldns="a.dns.tw";
		else
			ldns="."
		fi
	else
		ldns=${dns}
	fi
	exec 5>&1
	for x in $(dnstracer -4 -o -t 10 -r 1 -s $ldns $1 | tee >(cat - >&5) | awk '$4=="->"{print $5}'|sort|uniq); do
		if [ "$( echo $x | grep -E -o '([0-9]{1,3}[\.]){3}[0-9]{1,3}' )x" == "x" ] ; then 
			cname+=( $x )
		else
			triger=$((triger+1))
			nstracerip+=( $x )
		fi
	done
	#if [ ${triger} -eq 0 ] && [ ${#cname[*]} -gt 0 ] ; then #&& nscheck ${cname[${#cname[*]}-1]}	
	if [ ${#cname[*]} -gt 0 ] ; then #&& nscheck ${cname[${#cname[*]}-1]}	
		for x in $(printf "%s\n" ${cname[*]} | sort | uniq ) ; do
			nscheck $x
		done
	fi
}

j=0
while [ ${count} -eq 0 -o ${j} -lt ${count} ] ; do
	targetIP=()
	for((i=0;i<${#target[@]};i++)); do
		if [[ "${resolve[0]}x" == "x" ]] ; then
			if [[ "$( echo "${target[$i]%:*}" | grep -oE "([0-9]{1,3}[\.]){3}[0-9]{1,3}" )x" == "x"  ]] ; then 
				queryip "${target[$i]%:*}"
			else
				targetIP+=( "${target[$i]%:*}" )
				[[ ${querymap} -eq 1 ]] && queryipmap "${target[$i]%:*}"
			fi
		else
			targetIP+=( "${resolve[*]}" )
		fi
	done
	for((i=0;i<${#target[@]};i++)); do
		#if [ "$simp" -eq 1 -o "${target[$i]}" == "${targetIP[$i]}" ] ; then
		if [ "$simp" -eq 1 ] ; then
			main2 "${target[$i]}" "${url[$i]}"
		else
			if [ ${#targetIP[$i]} -gt 0 ]; then
				main "${target[$i]}" "${url[$i]}" "${targetIP[$i]}"
			fi
		fi
	done
	j=$((j+1))
	[ ${count} -eq 0 -o ${j} -lt ${count} ] &&  echo "Running Count: ${j}" && sleep $await;
done
