#!/usr/bin/expect
#author: @fightfa
#2017��9��13�� 22:01:56 ʵ�ָ��ֳ�������ʱ����ı��������ʾ��
#2017��9��12�� 20:24:06 ������ʾʵ�֡��Ż��������ɡ�
#2017��9��11�� ʵ��һ��run/debug��run������ɡ��ٶ� rebuild 2s~3s,�����Ķ�build�� 5s�����ű�2s 496ms����5s����
#�ؿ�˵����������
#�̳������http://www.jianshu.com/p/f8a939ad7efd
#CLion��Run/Debug��romote debug��romote run�����л�ʱ�������Զ��ر�gbd������ԭ�����е�Tab��Ҫ�ֶ��رգ�# TODO ������˵�ġ�
#Run/debug Configuraton ��remote debug�б����ֶ�ָ��Symbol file��elf�ļ�·����emote run����Symbol file�ÿա�
#����������ֶ�����Ӣ��д��
set now [clock clicks]
set timeout 8
#TODO * ����elf·��������CLion�е�gdb remote ��ʹCLion��gdb���ڡ�����ʵ�֡���
#TODO �Ż����������ʽ
#TODO  ������ܵ����ַ���пո�����˫���ŵĲ������������
#ע��������ĵ�ַ�����е���б/�滻Ϊ��б\��������win�е�ַ��\\��б��linux mac��expect shell��ֻ֧��/��б�ĵ�ַ��expectForWinҲ��
set num [regsub -all "\\\\" [lindex $argv 0] "\/" projectFileDir]
set num [regsub -all "\\\\" [lindex $argv 1] "\/" bin_path]
#action:ִ�ж�����-Run�� -Debug
set action [string tolower [lindex $argv 2]]
set bin_path $projectFileDir/$bin_path

#�������ϸ��ʽ���ո�{����}�ո񡷡���
# ���� } elseif ���ܲ�������
if {$action=="-debug"} {
    send_user ">>Action is Debug\n"
} elseif {$action=="-run"} {
    send_user ">>Action is Run\n"
} else {
    set action "-debug"
    send_user "\n>>warn: Unkown Action of \'$action\', now is default to Debug\nYou can set argv\[1\]  \'-run\' or \'-debug\' \n"
}

global MessageBeep
set MessageBeep $projectFileDir/MessageBeep.exe
proc beepError {} {
    global MessageBeep
    exec $MessageBeep 16
}
proc beepSucceed {} {
    global MessageBeep
    exec $MessageBeep 64
}
#proc beepOk{} {
#    global MessageBeep
##    0 ��������ʵ��������warn�ϡ���
#    exec $MessageBeep 0
#}

#������һ������ʾbuild���
#beepOk

#������openocd�Ự�ĺ�����

proc exitSession {code} {
    #�����Ự���������Ự���ܻᵼ���´���¼ʱsend�����#TODO ��֤��ߡ�
    send "exit\n"
    expect "Connection closed by foreign host"
    set timeout 0
    exit $code
}
#TODO ������send_error $expect(0,string) ԭ��δ֪
#TODO send_error ż����ʾ��������exit�� ԭ��δ֪
proc abort {str} {
    beepError
    send_error \n$str
    global timeout
    exitSession 1
}
proc abortTimeout {} {
    global timeout
    beepError
    puts "\n"
    send_error "\n>>error:timeout ${timeout}s! please check the above, or:\nyou may try extend the timeout value (or set -1 to be not timeout) and run again."
    exitSession 2
}
proc abortCatch {str} {
    beepError
    send_error "\n>>error:process is interrupted because catch the follow from above :"
    send_user \n$str
    global timeout
    exitSession 1
}
#TODO openocd���̶����������expect sendָ�����ֻ�������������kill openocd�������⡣
proc abortWithTips {} {
        abort "failed! please CHECK THE ABOVE, or:\n1.Power on your board,or relink usb port;\n2.Close tool gdb, Rerun tool OpenOCD.or Ctrl+Shift+Esc,kill the openocd process.\n3.Modify or comment this line in expect.writeflash.sh and rerun\n"
}
#����1����¼������Ự
spawn telnet localhost 4444
#��������������д���Ῠ��3��4�롣����
#expect { ">" {}
expect {
    -re "\ntelnet: Unable to connect to remote host.*\n>" {
        abortWithTips
    }
    ">" {}
    timeout {abortTimeout}
}
#����2����λ����
send "reset init\n"
#send "reset\n"
#send "init\n"
#send "halt\n"
#timeout {abortTimeout}  ����ǰ�����4s������
#������^��\Aƥ�俪ͷ����
expect {
   -nocase -re "\n(error|failed).*>" {
        abortWithTips
    }
    ">" {}
     timeout {abortTimeout}
}
#����3����¼bin�ļ�������
send "flash write_image erase $bin_path 0x8000000\n"
expect {
        -nocase -re "\nwrote(.*)>" {
            #������һ������ʾ��д���
            beepSucceed
        }
        -nocase  -re "\n(error|failed|couldn't open.*)>" {
            abortCatch $expect_out(1,string)
        }
        timeout {abortTimeout}
}
#TODO ��һָ������漸��ָ��ż�����л���ֶ�һ�� >�ַ���������ʾ��Ϣ��ʱ�ظ���������˳�򡣡�Ӱ�첻��
#����4����¼�귢����ָ�������
if {$action=="-debug"} {
#������ϵ���ԣ�
    send "halt\n"
    expect ">"
    #�򿪵���ͨ��ģʽ������CLion�·���OpenOCD�����п�������trace_puts�ȵķ�����Ϣ���������ӡ�
    send "arm semihosting enable\n"
    expect ">"
} elseif {$action=="-run"} {
#������ֱ�����У�����edit configurations->remote run �� Symbol file���뱣��Ϊ��
#�����пɲ��ӣ�
#    send "reset\n"
#    expect ">"
#�򿪵���ͨ��ģʽ��������CLion�·���OpenOCD�����п�������trace_puts�ȵķ�����Ϣ�������õ���ɹء�
    send "arm semihosting enable\n"
#    send "arm semihosting disable\n"
    expect ">"
}
#����5�����㱾�ű�����ʱ�䣬������Buildʱ�� #TODO * ����Buildʱ��ķ���
set time [expr [clock clicks]-$now]
set seconds [expr $time/1000]
set millis [expr $time%1000]
set now [clock format [clock seconds] -format {%H:%M:%S}]
#send_user "\n>>w ��д�ɹ�����ʱ ${seconds}s ${millis}ms\n"
send_user "\n>>$now Write Flash finished in ${seconds}s ${millis}ms\n"

#expect off
exitSession 0
