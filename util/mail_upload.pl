#!/usr/bin/env perl

use Jcode;

###############################################################################
# ����

# ������Ԥ�Ķ��˹�碌�ƽ񤭴����Ƥ���������
# �ǥե���ȤǤ� http://192.168.2.1:8080/up/ �����֤�����������ˤʤ�
# �Ƥ��ޤ���
use constant HOST       => '192.168.2.1:8080'; # �ۥ���̾
use constant PATH       => '/up'; # �ѥ�
###############################################################################

my $post_data;

while (<>) {
    $post_data .= $_;
}

$post_data = jcode($post_data)->euc;
$post_data =~ s/\r\n/\n/g;
$post_data =~ s/\n/\r\n/g;

print <<"__TEXT__";
POST @{[PATH]}/mail_upload/ HTTP/1.1
Host: @{[HOST]}
Connection: Close
Content-Length: @{[length($post_data) + 1]}

@{[$post_data]}
__TEXT__


