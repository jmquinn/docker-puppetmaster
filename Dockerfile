FROM ubuntu:14.04
MAINTAINER Arcus "http://arcus.io"
RUN echo "deb http://archive.ubuntu.com/ubuntu trusty main universe multiverse" > /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y wget
RUN wget -q http://apt.puppetlabs.com/puppetlabs-release-trusty.deb -O /tmp/puppetlabs.deb
RUN dpkg -i /tmp/puppetlabs.deb
RUN apt-get update
RUN apt-get -y install mysql-client-5.5 libdbd-mysql-perl libdbi-perl
#RUN apt-get -y install puppetmaster-passenger puppet-dashboard puppetdb puppetdb-terminus redis-server supervisor openssh-server net-tools mysql-server mysql-client
RUN apt-get --force-yes -y install tzdata=2014b-1
RUN apt-get -y install puppetmaster-passenger puppetdb puppetdb-terminus redis-server supervisor openssh-server net-tools mysql-server mysql-client openjdk-7-jre-headless tzdata-java
RUN apt-get -y install git ruby2.0
RUN ln -s /usr/bin/gem2.0 /usr/bin/gem -f
RUN ln -s /usr/bin/ruby2.0 /usr/bin/ruby -f
RUN git clone git://github.com/puppetlabs/puppet-dashboard.git /usr/share/puppet-dashboard

#no puppet-dashboard package, so we must do it manually
RUN useradd puppet-dashboard
#RUN cd /usr/share/puppet-dashboard && git fetch && git checkout v1.2.0 && chown -R puppet-dashboard:puppet-dashboard /usr/share/puppet-dashboard && bundle install
RUN cd /usr/share/puppet-dashboard && gem install bundle
RUN cd /usr/share/puppet-dashboard && gem install eventmachine
RUN cd /usr/share/puppet-dashboard && chown -R puppet-dashboard:puppet-dashboard /usr/share/puppet-dashboard && bundle install
RUN gem install --no-ri --no-rdoc hiera hiera-puppet redis hiera-redis hiera-redis-backend
RUN echo "127.0.0.1 localhost puppet puppetdb puppetdb.local puppet.local" > /etc/hosts
RUN mkdir /var/run/sshd
ADD supervisor.conf /opt/supervisor.conf
ADD auth.conf /etc/puppet/auth.conf
ADD puppet.conf /etc/puppet/puppet.conf
ADD puppetdb.conf /etc/puppet/puppetdb.conf
RUN (sed -i 's/#host = localhost/host = 0.0.0.0/g' /etc/puppetdb/conf.d/jetty.ini)
ADD routes.yaml /etc/puppet/routes.yaml
ADD hiera.yaml /etc/hiera.yaml

RUN (start-stop-daemon --start -b --exec /usr/sbin/mysqld && sleep 5 ; echo "create database dashboard character set utf8;" | mysql -u root)
RUN (start-stop-daemon --start -b --exec /usr/sbin/mysqld && sleep 5 ; echo "create user dashboard@'localhost' identified by '2PJXWACQS7';" | mysql -u root)
RUN (start-stop-daemon --start -b --exec /usr/sbin/mysqld && sleep 5 ; echo "grant all on dashboard.* to dashboard@'%';" | mysql -u root)
ADD database.yml /usr/share/puppet-dashboard/config/database.yml
RUN (start-stop-daemon --start -b --exec /usr/sbin/mysqld && cd /usr/share/puppet-dashboard && RAILS_ENV=production rake db:migrate)
RUN (sed -i 's/.*START.*/START=yes/g' /etc/default/puppet-dashboard)
RUN (sed -i 's/.*START.*/START=yes/g' /etc/default/puppet-dashboard-workers)

RUN mkdir /root/.ssh
# NOTE: change this key to your own
ADD sshkey.pub /root/.ssh/authorized_keys
RUN chown root:root /root/.ssh/authorized_keys
ADD run.sh /usr/local/bin/run

EXPOSE 22
EXPOSE 3000
EXPOSE 8080
EXPOSE 8081
EXPOSE 8140
CMD ["/usr/local/bin/run"]
