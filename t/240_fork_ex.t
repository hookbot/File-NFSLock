# Exclusive Fork Test
#
# This tests the capabilities of fork after lock to
# ensure both parent and child retain the exclusive lock.

use strict;
use warnings;
use File::Temp qw(tempfile);

use Test::More tests => 6;
use File::NFSLock;
use Fcntl qw(O_CREAT O_RDWR O_RDONLY O_TRUNC O_APPEND LOCK_EX LOCK_SH LOCK_NB);

$| = 1; # Buffer must be autoflushed because of fork() below.

my $datafile = (tempfile)[1];

# Wipe lock file in case it exists
unlink ("$datafile$File::NFSLock::LOCK_EXTENSION");

# Create a blank file
sysopen ( my $fh, $datafile, O_CREAT | O_RDWR | O_TRUNC );
close ($fh);
ok (-e $datafile && !-s _);

{
  # Forced dummy scope
  my $lock1 = new File::NFSLock {
    file => $datafile,
    lock_type => LOCK_EX,
  };

  ok ($lock1);

  my $pid = fork;
  if (!defined $pid) {
    die "fork failed!";
  } elsif (!$pid) {
    # Child process

    # Test possible race condition
    # by making parent reach newpid()
    # and attempt relock before child
    # even calls newpid() the first time.
    sleep 2;
    $lock1->newpid;

    # Act busy for a while
    sleep 5;

    # Now release lock
    exit;
  } else {
    # Fork worked
    ok 1;
    # Avoid releasing lock
    # because child should do it.
    $lock1->newpid;
  }
}
# Lock is out of scope, but
# should still be acquired.

# Try to get a non-blocking lock.
# Yes, it is the same process,
# but it should have been delegated
# to the child process.
# This lock should fail.
{
  # Forced dummy scope
  my $lock2 = new File::NFSLock {
    file => $datafile,
    lock_type => LOCK_EX|LOCK_NB,
  };

  ok (!$lock2);
}

# Wait for child to finish
ok(wait);

# Try again now that the child is done.
# This time it should work.
{
  # Forced dummy scope
  my $lock2 = new File::NFSLock {
    file => $datafile,
    lock_type => LOCK_EX|LOCK_NB,
  };

  ok($lock2);
}

# Wipe the temporary file
unlink $datafile;
