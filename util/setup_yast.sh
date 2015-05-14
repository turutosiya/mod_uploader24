#!/usr/bin/env zsh

unsetopt FUNCTION_ARGZERO

run() {
    echo "$0: running \`$@'"
    $@ || exit -1
}

host=$1
sudo_yast="env TERM=${TERM} sudo /sbin/yast"

# �������Ѥθ���ž��
run ssh-copy-id -i ~/.ssh/vmware.id_rsa ${host}

# Subversion ���������Ѥθ���ž��
run ssh ${host} "rm -f .ssh/svn.id_rsa"
run scp ~/.ssh/svn.id_rsa ${host}:.ssh/
run ssh ${host} "rm -f .ssh/svn.id_rsa.pub"
run scp ~/.ssh/svn.id_rsa.pub ${host}:.ssh/
run scp =(echo "Host columbia";
          echo "Port 443";
          echo "IdentityFile ~/.ssh/home.id_rsa") ${host}:.ssh/config

# ���ܥġ���Υ��󥹥ȡ���
run ssh ${host} "${sudo_yast} --install zsh"
run ssh ${host} "${sudo_yast} --install emacs-nox"
run ssh ${host} "${sudo_yast} --install subversion"

# Z Shell �δĶ���������
run ssh ${host} "sudo chsh -s /bin/zsh ${USER}"
run scp =(echo "PROMPT='%{$fg[$(load_color)]%}%B$USER@%m%#%b '";
          echo "autoload -U compinit";
          echo "compinit -u";
          echo "HISTFILE=$HOME/.zsh_history";
          echo "HISTSIZE=1000000";
          echo "SAVEHIST=1000000";
          echo "setopt share_history") ${host}:.zshrc
run scp =(echo "export LANG=C";
          echo "export PATH=$PATH:$HOME/bin") ${host}:.zshenv

# keychain �򥤥󥹥ȡ���
run ssh ${host} "mkdir -p bin"
run scp /usr/bin/keychain ${host}:bin/

# known_hosts ���ɲ�
run ssh ${host} "ssh-keyscan -p 443 -t rsa columbia > .ssh/known_hosts"
run ssh ${host} "ssh-keyscan -H -p 443 -t rsa columbia >> .ssh/known_hosts"

# mod_uploader ��ɬ�פʥѥå������Υ��󥹥ȡ���
run ssh ${host} "${sudo_yast} --install gcc-c++"
run ssh ${host} "${sudo_yast} --install make"
run ssh ${host} "${sudo_yast} --install libtool"
run ssh ${host} "${sudo_yast} --install apache2-devel"

run ssh ${host} "${sudo_yast} --install nkf"
run ssh ${host} "${sudo_yast} --install perl-libwww-perl"
run ssh ${host} "${sudo_yast} --install lsb"

# NOTE: �ƥ��Ȥ�ɬ�פ� Perl WWW::Mechanize �� CPAN �ǥ��󥹥ȡ��뤹��

# ��ݥ��ȥ꤫������å�������
run ssh ${host} "bin/keychain ~/.ssh/*.id_rsa"
run ssh ${host} "mkdir -p prog"
run ssh ${host} "source ~/.keychain/${host}*-sh; cd prog; svn co svn+ssh://svn@columbia/storage/svn/repos/prog/Apache"
