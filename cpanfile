requires 'perl',                      '5.010';
requires 'DateTime',                  '1.36';
requires 'DateTime::Format::ISO8601', '0.08';
requires 'DBIx::Class',               '0.082840';

on test => sub {
   requires 'Test::More',  '0.88';
   requires 'Path::Tiny',  '0.096';
   requires 'DBD::SQLite', '1.50';
};

on develop => sub {
   requires 'Path::Tiny',        '0.096';
   requires 'Template::Perlish', '1.52';
};
