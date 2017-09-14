#!/usr/bin/expect
#author: @fightfa
#2017年9月13日 22:01:56 实现各种常见下载时问题的报错红字提示。
#2017年9月12日 20:24:06 声音提示实现。优化代码快完成。
#2017年9月11日 实现一键run/debug，run配置完成。速度 rebuild 2s~3s,少量改动build则 5s，本脚本2s 496ms，总5s左右
#必看说明：！！！
#教程详见：http://www.jianshu.com/p/f8a939ad7efd
#CLion中Run/Debug的romote debug和romote run互相切换时不能先自动关闭gbd窗口中原已运行的Tab，要手动关闭！# TODO 解决左边说的。
#Run/debug Configuraton 中remote debug中必须手动指定Symbol file即elf文件路径，emote run中则Symbol file置空。
#窗口输出文字都用了英文写。
set now [clock clicks]
set timeout 8
#TODO * 传入elf路径参数给CLion中的gdb remote 再使CLion开gdb窗口。（难实现。）
#TODO 优化参数传入格式
#TODO  处理可能的因地址含有空格而须带双引号的参数处理的问题
#注：将传入的地址中所有的左斜/替换为右斜\，由于在win中地址是\\左斜，linux mac中expect shell等只支持/右斜的地址，expectForWin也是
set num [regsub -all "\\\\" [lindex $argv 0] "\/" projectFileDir]
set num [regsub -all "\\\\" [lindex $argv 1] "\/" bin_path]
#action:执行动作：-Run或 -Debug
set action [string tolower [lindex $argv 2]]
set bin_path $projectFileDir/$bin_path

#必须是严格格式《空格{》《}空格》。。
# 保持 } elseif 才能不报错。。
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
##    0 这声音其实更常用在warn上。。
#    exec $MessageBeep 0
#}

#发出铛一声，提示build完成
#beepOk

#结束与openocd会话的函数：

proc exitSession {code} {
    #结束会话，不结束会话可能会导致下次烧录时send出错吧#TODO 验证左边。
    send "exit\n"
    expect "Connection closed by foreign host"
    set timeout 0
    exit $code
}
#TODO 不能是send_error $expect(0,string) 原因未知
#TODO send_error 偶尔显示不出来就exit了 原因未知
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
#TODO openocd进程多次启动导致expect send指令出错，只能任务管理器中kill openocd进程问题。
proc abortWithTips {} {
        abort "failed! please CHECK THE ABOVE, or:\n1.Power on your board,or relink usb port;\n2.Close tool gdb, Rerun tool OpenOCD.or Ctrl+Shift+Esc,kill the openocd process.\n3.Modify or comment this line in expect.writeflash.sh and rerun\n"
}
#步骤1：登录建立与会话
spawn telnet localhost 4444
#不能如下行这样写，会卡上3、4秒。。。
#expect { ">" {}
expect {
    -re "\ntelnet: Unable to connect to remote host.*\n>" {
        abortWithTips
    }
    ">" {}
    timeout {abortTimeout}
}
#步骤2：复位板子
send "reset init\n"
#send "reset\n"
#send "init\n"
#send "halt\n"
#timeout {abortTimeout}  这句放前面会慢4s。。。
#不能用^或\A匹配开头。。
expect {
   -nocase -re "\n(error|failed).*>" {
        abortWithTips
    }
    ">" {}
     timeout {abortTimeout}
}
#步骤3：烧录bin文件到板子
send "flash write_image erase $bin_path 0x8000000\n"
expect {
        -nocase -re "\nwrote(.*)>" {
            #发出铛一声，提示烧写完成
            beepSucceed
        }
        -nocase  -re "\n(error|failed|couldn't open.*)>" {
            abortCatch $expect_out(1,string)
        }
        timeout {abortTimeout}
}
#TODO 上一指令和下面几个指令偶尔运行会出现多一个 >字符。导致显示信息有时重复和乱了行顺序。。影响不大。
#步骤4：烧录完发下面指令给板子
if {$action=="-debug"} {
#下载完断点调试：
    send "halt\n"
    expect ">"
    #打开调试通信模式，可以CLion下方的OpenOCD窗口中看到接收trace_puts等的返回信息，这里必须加。
    send "arm semihosting enable\n"
    expect ">"
} elseif {$action=="-run"} {
#下载完直接运行，其中edit configurations->remote run 中 Symbol file必须保持为空
#这两行可不加：
#    send "reset\n"
#    expect ">"
#打开调试通信模式，可以在CLion下方的OpenOCD窗口中看到接收trace_puts等的返回信息，若不用到则可关。
    send "arm semihosting enable\n"
#    send "arm semihosting disable\n"
    expect ">"
}
#步骤5：计算本脚本运行时间，不包括Build时间 #TODO * 计入Build时间的方法
set time [expr [clock clicks]-$now]
set seconds [expr $time/1000]
set millis [expr $time%1000]
set now [clock format [clock seconds] -format {%H:%M:%S}]
#send_user "\n>>w 烧写成功！耗时 ${seconds}s ${millis}ms\n"
send_user "\n>>$now Write Flash finished in ${seconds}s ${millis}ms\n"

#expect off
exitSession 0
