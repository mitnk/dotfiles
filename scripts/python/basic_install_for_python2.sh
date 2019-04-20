#
# install setuptools and pip for Python 2.X
#

sudo echo && \
mkdir -p ~/tmp && \
cd ~/tmp/ && \
wget https://pypi.python.org/packages/source/s/setuptools/setuptools-1.4.1.tar.gz  && \
tar xf setuptools-1.4.1.tar.gz && \
cd setuptools-1.4.1/  && \
sudo python setup.py install && \
cd .. && \
sudo rm -rf setuptools-1.4.1* && \
sudo easy_install pip && \
sudo pip install ipython && \
sudo easy_install readline
