requires 'perl', 'v5.40';

requires 'Const::Fast';
requires 'IPC::Run3';
requires 'Path::Tiny';
requires 'IO::Handle';
requires 'Data::Dumper::Names';
requires 'Devel::StackTrace::WithLexicals';
requires 'Class::Exporter';
requires 'Syntax::Keyword::Defer';
requires 'Object::Pad';
requires 'Regexp::Common';

on test => sub {
    requires 'Test::More', '0.96';
    requires 'Test::CPAN::Meta';
    requires 'Test::Pod';
    requires 'Test::MinimumVersion::Fast';
};

on develop => sub {
    requires 'Perl::Critic';
    requires 'Perl::Critic::Community';
    requires 'Perl::Tidy';
    requires 'Carmel';
    requires 'Dist::Milla';
}

