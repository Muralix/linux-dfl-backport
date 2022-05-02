Name:               linux-dfl-backport
Version:            %{getenv:BACKPORT_VERSION}
Release:            1
Summary:            Backported fpga drivers from linux-dfl
License:            GPLv2
Group:              System/Kernel and hardware
URL:                https://github.com/OPAE/linux-dfl-backport/
BuildArch:          noarch
Requires:           dkms, (kernel-devel if kernel), (kernel-rt-devel if kernel-rt)

%define _dstdir %{_usrsrc}/linux-dfl-backport-%{version}-%{release}
%define _pkgdir %{buildroot}%{_dstdir}
%define _dracut %{_prefix}/lib/dracut/dracut.conf.d/90-linux-dfl-backport.conf

%description
A backport of DFL FPGA drivers from the current LTS branch of
https://github.com/OPAE/linux-dfl-backport/.

%install
install -d %{_pkgdir}
cp -a LICENSE Makefile drivers include %{_pkgdir}
cp -a build/dkms/dkms-postinst.sh build/dkms/dkms-postrem.sh %{_pkgdir}
cp -a build/dkms/dkms-preinst.sh build/dkms/generate-dkms-conf.sh %{_pkgdir}
sed -E 's/PKGVER/%{version}-%{release}/' build/dkms/dkms.conf.in > %{_pkgdir}/dkms.conf
install -d $(dirname %{buildroot}%{_dracut})
echo 'omit_drivers+="%_modules"' > %{buildroot}%{_dracut}

%post
dkms add %{name}/%{version}-%{release} --rpm_safe_upgrade --no-initrd
dkms install %{name}/%{version}-%{release} --rpm_safe_upgrade --no-initrd

%preun
dkms remove %{name}/%{version}-%{release} --rpm_safe_upgrade --no-initrd --all

%postun
rmdir %{_dstdir}

%files
%defattr(-,root,root)
%{_dstdir}/*
%{_dracut}
