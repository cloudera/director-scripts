#
# Check that everything is working
#
echo "Running sanity checks:"

hostname -f
if [ $? != 0 ]
then
    echo "Unable to run the command 'hostname -f' (check 1 of 4)"
    exit 1
fi

hostname -i
if [ $? != 0 ]
then
    echo "Unable to run the command 'hostname -i' (check 2 of 4)"
    exit 1
fi

host "$(hostname -f)"
if [ $? != 0 ]
then
    echo "Unable to run the command 'host \`hostname -f\`' (check 3 of 4)"
    exit 1
fi

host "$(hostname -i)"
if [ $? != 0 ]
then
    echo "Unable to run the command 'host \`hostname -i\`' (check 4 of 4)"
    exit 1
fi

echo "Everything is working!"
exit 0