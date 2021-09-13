requires 'perl',                      '5.010';
requires 'DateTime',                  '1.36';
requires 'DateTime::Format::ISO8601', '0.08';
requires 'DBIx::Class',               '0.082840';
requires 'DateTime::Format::SQLite',  '0.11';
requires 'Template::Perlish',         '1.52';
requires 'Try::Tiny',                 '0.27';

on test => sub {
   requires 'Test::More',      '0.88';
   requires 'Test::Exception', '0.43';
   requires 'Path::Tiny',      '0.096';
   requires 'DBD::SQLite',     '1.50';
};

on develop => sub {
   requires 'Path::Tiny',        '0.096';
   requires 'Template::Perlish', '1.52';
   requires 'Test::Pod';
   requires 'Test::Pod::Coverage';
};
