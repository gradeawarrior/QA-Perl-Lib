cpan_list="./cpan_modules.list";
cpan_file=$(which cpan);
cpan_term_args=$*;

for i in `cat $cpan_list`
do
	cat <<EOF
	==============
	>> cpan $i
	==============

\$ cpan $cpan_term_args $i;
EOF
	cpan $cpan_term_args $i;
	
	cat <<EOF

	>> DONE! Finished installing $i

EOF

	#sudo chmod 755 $cpan_file;
	#sleep 3;

done
