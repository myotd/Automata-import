#!/bin/bash

escript=/tmp/otd$$
user=`id -un`

if [ $# -lt 2 ]
  then
    echo only $# args
    echo "usage: $0 {client} {automata,...}"
    exit
fi

Site=$1
shift
esc_automata=""

echo "Site: "$Site
echo "User: $user"
echo "Automaten:"
for automata in "$@"
do
  echo - $automata
  esc_automata+=$(printf '\\"%q\\" ' "$automata") # Escape filename like bash
  # echo $esc_automata
done

echo  -n "password?" && read -s cred

cat <<OTD > $escript
log_user 0
set timeout 15
set send_human {.1 .3 1 .05 2}

spawn ss 
expect {
   "started" { send "cp $esc_automata /home/ipcenter/.ipcenter_shell/$user/ 2>&1\r" }
   "password" { send $cred\r ; exp_continue }
   timeout { puts "\nError timeout ss" ; exit}
   eof { puts "\nss failed" ; exit}
}

expect {
  "# " { send "exit\r"}
  timeout { puts "\nNo exit from ss" ; exit }
}

spawn ssh $user@localhost -p 2222
expect {
   "yes/no" { send "yes\r" ; exp_continue }
   "password:" { send $cred\r }
   timeout { puts "\nError timeout login" ; exit}
   eof { puts "\nError no connection" ; exit }
}
expect { 
    "]>" { send -h "\r" }
    timeout { puts "timeout help\n" }
}
puts "\n Starting Import\r";
log_user 1
set timeout 30
OTD

for automata in "$@"
do
  exp_cmd="importAutomatonToClient(\\\"$automata\\\",\\\"$Site\\\");" 
cat <<INL >> $escript
expect "]>"
send "$exp_cmd\r"
INL
done

cat <<EXP >>$escript
expect "]>" 
puts "\nclosing...\r"
close
wait
exit
EXP

expect -f $escript
rm $escript
exit