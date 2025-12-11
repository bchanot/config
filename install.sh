#!/bin/sh

if [ -z $1 ]; then
	echo "Usage: $0 {server|linux|arm|osx}"
	exit 1
fi

sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get install -y vim git gcc make pkg-config unzip dkms git-lfs

echo "Save older config in ~/Oldconfig ( with '.' like \".vimrc\" )"
rm -rf $HOME/Oldconfig 2>&-
mkdir -p $HOME/Oldconfig
mv $HOME/.vim $HOME/Oldconfig 2>&-
mv $HOME/.Sublivim $HOME/Oldconfig 2>&-
mv $HOME/.vimrc $HOME/Oldconfig 2>&-
mv $HOME/.bashrc $HOME/Oldconfig 2>&-

echo "Create new vim architecture"
mkdir -p $HOME/.vim/autoload $HOME/.vim/colors $HOME/.vim/syntax $HOME/.vim/plugin $HOME/.vim/spell $HOME/.vim/config $HOME/.vim/bundle

echo "Cloning some git repositories"
#git clone --quiet https://github.com/tpope/vim-pathogen $HOME/.vim/pathogen
git clone --quiet https://github.com/vim-syntastic/syntastic $HOME/.vim/bundle/syntastic
git clone --quiet https://github.com/tomasr/molokai /tmp/molokai
git clone --quiet https://github.com/preservim/nerdtree /tmp/nerdtree

echo "Building new vim"
cp -rupv ./vim/* $HOME/.vim
#ln -s $HOME/.vim/pathogen/autoload/pathogen.vim $HOME/.vim/autoload/pathogen.vim
cp /tmp/molokai/colors/molokai.vim $HOME/.vim/colors
cp /tmp/nerdtree $HOME/.vim/bundle/
ln -s $HOME/.vim/vimrc $HOME/.vimrc

if [ "$1" == "server" ]; then
	cp /tmp/config/bash/bashrc-server $HOME/.bashrc
elif [ "$1" == "linux" -o "$1" == "arm" ]; then
	cp bash/bashrc-linux $HOME/.bashrc
elif [ "$1" == "osx" ]; then
	cp /tmp/config/bash/bashrc-osx $HOME/.bashrc
fi

echo "Deleting temporary files"
rm -rf /tmp/molokai

source $HOME/.bashrc
echo "Ïf you are running zsh, please change for bash =)"
echo "Enjoy !"
