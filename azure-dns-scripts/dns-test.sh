#
# Check that everything is working
#
echo "Running sanity checks:"

if ! hostname -f
then
    echo "Unable to run the command 'hostname -f' (check 1 of 4)"
    exit 1
fi

if ! hostname -i
then
    echo "Unable to run the command 'hostname -i' (check 2 of 4)"
    exit 1
fi

if ! host "$(hostname -f)"
then
    echo "Unable to run the command 'host \`hostname -f\`' (check 3 of 4)"
    exit 1
fi

if ! host "$(hostname -i)"
then
    echo "Unable to run the command 'host \`hostname -i\`' (check 4 of 4)"
    exit 1
fi

echo ""
echo "Everything is working!"
exit 0
