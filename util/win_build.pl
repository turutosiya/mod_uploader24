#!/usr/bin/env perl
###############################################################################
# Copyright (C) 2006 Tetsuya Kimata <kimata@acapulco.dyndns.org>
#
# All rights reserved.
#
# This software is provided 'as-is', without any express or implied
# warranty.  In no event will the authors be held liable for any
# damages arising from the use of this software.
#
# Permission is granted to anyone to use this software for any
# purpose, including commercial applications, and to alter it and
# redistribute it freely, subject to the following restrictions:
#
# 1. The origin of this software must not be misrepresented; you must
#    not claim that you wrote the original software. If you use this
#    software in a product, an acknowledgment in the product
#    documentation would be appreciated but is not required.
#
# 2. Altered source versions must be plainly marked as such, and must
#    not be misrepresented as being the original software.
#
# 3. This notice may not be removed or altered from any source
#    distribution.
#
# $Id: win_build.pl 1928 2006-11-04 14:47:16Z svn $
###############################################################################

use strict;

use Expect;
use Term::ReadLine;
use Term::ReadPassword;

use constant CMD_TIMEOUT_SEC    => 5;
use constant MAKE_TIMEOUT_SEC   => 3600;
use constant WINDOWS_HOSTNAME   => 'brazil';
use constant VSVARS2003_PATH    => 'C:/Develop/IDE/VisualStudio2003/Common7/Tools/vsvars32.bat';
use constant VSVARS2008_PATH    => 'C:/Develop/IDE/VisualStudio2008/Common7/Tools/vsvars32.bat';
use constant DISK_DEVICE        => 'Z:';
use constant DISK_PATH          => '\\\\columbia\\kimata';
use constant MOD_UPLOADER_PATH  => 'Z:/prog/Apache/Uploader2';

sub get_pass {
    return read_password(qq|pass: |);
}

sub create_exp {
    my $exp = Expect->new();
    $exp->raw_pty(0);
    return $exp;
}

sub ssh_login {
    my $exp = shift;
    my $pass = shift;

    $exp->spawn('cocot', qw(-t EUC-JP -p CP932 ssh), WINDOWS_HOSTNAME) or die $!;
    $exp->expect(CMD_TIMEOUT_SEC, 'password:') or die $!;
    $exp->send($pass . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, 'successfully');
}

sub mount_disk {
    my $exp = shift;
    my $user = shift;
    my $pass = shift;

    $exp->send('net use ' . DISK_DEVICE . ' ' . quotemeta(DISK_PATH) .
               ' /USER:' . $user . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '$');
}

sub init_tree {
    my $exp = shift;

    $exp->send('base_dir=`mktemp -d $TEMP/mod_uploader.XXXXXX`' . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '$');

    $exp->send('cp -pr ' . MOD_UPLOADER_PATH . '/work/mod_uploader/* ' .
               '$base_dir' . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '$');
}

sub cd_src_dir {
    my $exp = shift;

    $exp->send('cd $base_dir/src' . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '$');
}

sub cd_util_dir {
    my $exp = shift;

    $exp->send('cd $base_dir/util' . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '$');
}

sub set_module_env {
    my $exp = shift;

    $exp->send('cmd' . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '>');

    $exp->send(VSVARS2003_PATH . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '>');
}

sub exit_cmd {
    my $exp = shift;

    $exp->send('exit' . "\n");
    $exp->expect(MAKE_TIMEOUT_SEC, '$');
}

sub compile_module {
    my $exp = shift;

    $exp->send('make -f GNUmakefile.win32 clean' . "\n");
    $exp->expect(MAKE_TIMEOUT_SEC, 'src>');

    $exp->send('make -f GNUmakefile.win32 mod_uploader-ap2.0.so' . "\n");
    $exp->expect(MAKE_TIMEOUT_SEC, 'src>');

    $exp->send('make -f GNUmakefile.win32 clean-obj' . "\n");
    $exp->expect(MAKE_TIMEOUT_SEC, 'src>');

    $exp->send('make -f GNUmakefile.win32 mod_uploader-ap2.2.so' . "\n");
    $exp->expect(MAKE_TIMEOUT_SEC, 'src>');
}

sub set_installer_env {
    my $exp = shift;

    $exp->send('cmd' . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '>');

    $exp->send(VSVARS2008_PATH . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '>');
}

sub compile_utility {
    my $exp = shift;

    $exp->send('msbuild UploaderConfig/UploaderConfig.csproj /p:Configuration=Release /t:Rebuild 2>&1' . "\n");
    $exp->expect(MAKE_TIMEOUT_SEC, 'util>');
}

sub compile_installer {
    my $exp = shift;

    $exp->send('devenv /build release UploaderConfigSetup/UploaderConfigSetup.vdproj 2>&1' . "\n");
    $exp->expect(MAKE_TIMEOUT_SEC, 'util>');
}

sub copy_binary {
    my $exp = shift;

    $exp->send('cp -f $base_dir/*.msi ' . MOD_UPLOADER_PATH . '/' . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '$');
    $exp->send('cp -f $base_dir/src/*.so ' . MOD_UPLOADER_PATH . '/src/' . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '$');
}

sub clean_tree {
    my $exp = shift;

    $exp->send('cd $base_dir/..' . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '$');
    $exp->send('rm -rf $base_dir' . "\n");
    $exp->expect(CMD_TIMEOUT_SEC, '$');
}

my $user = $ENV{'USER'};
my $pass = $ENV{'WIN_PASS'} || get_pass();
my $exp = create_exp();

my $temp_dir = `mktemp -d -t mod_uploader.XXXXXX 2>/dev/null`;
chomp($temp_dir);

# NOTE:
# Samba ��ͳ�����٤��Τǡ��ĥ꡼�� Windows �Υ�����ɥ饤�֤�
# ���ԡ����Ƥ��饳��ѥ����Ԥ���

# �ĥ꡼�ν���
system("rm -rf work; ln -s $temp_dir work");
system("svn export . work/mod_uploader");
system("cd work/mod_uploader; ./configure --enable-thumbnail");

# ������
ssh_login($exp, $pass);
# # �ǥ������Υޥ����
# mount_disk($exp, $user, $pass);
# �ĥ꡼�ν���
init_tree($exp);

cd_src_dir($exp);
# �Ķ��ѿ��Υ��å�
set_module_env($exp);
# �⥸�塼��Υ���ѥ���
compile_module($exp);
exit_cmd($exp);

# �ǥ��쥯�ȥ�ΰ�ư
cd_util_dir($exp);
# �Ķ��ѿ��Υ��å�
set_installer_env($exp);
# ����ġ���Υ���ѥ���
compile_utility($exp);
# ���󥹥ȡ���Υ���ѥ���
compile_installer($exp);
exit_cmd($exp);

# ���������Х��ʥ�ե�����Υ��ԡ�
copy_binary($exp);
# �ĥ꡼�κ��
clean_tree($exp);

system("rm -rf work $temp_dir");

# Local Variables:
# mode: cperl
# coding: euc-japan-unix
# End:
