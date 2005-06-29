use ExtUtils::MakeMaker;
WriteMakefile(
	NAME => "Term::TUI",
	VERSION_FROM => "TUI.pm",
	($] >= 5.005
	   ? (ABSTRACT   => 'User interface based on Term::ReadLine',
	      AUTHOR     => 'Sullivan Beck (sbeck@cpan.org)')
	   : ()),
	'dist' => {COMPRESS=>'gzip',SUFFIX=>'gz'}
);
