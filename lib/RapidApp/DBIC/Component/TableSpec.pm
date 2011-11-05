package RapidApp::DBIC::Component::TableSpec;
#use base 'DBIx::Class';
# this makes Attribute::Handlers
require base; base->import('DBIx::Class');

#use Moose;
#use MooseX::NonMoose;
#use namespace::autoclean;
#extends 'DBIx::Class';
#no strict 'refs';
=pod
[15:44] <vs> Attribute::Handlers with DBIC Component classes, is there a trick to get it to work properly? I want to be able to have custom attributes defined in a separate package, and then include it it with use base, or load_componenets, or anything that will actually work, and have those attributes available for setting on the subs in the DBIC class... Sub::Attribute works, but has less features than Attribute::Handlers... is there a reason it doesn't work with Attribute::Hanlders?
[15:45] <alnewkirk> vs, ... wtf?
[15:45] <vs> heh
[15:46] <alnewkirk> vs, DBIC already does this without any extra modules needed
[15:48] <vs> ok.... how/where?
[15:49] <vs> to clearify, I'm not talking about class accessors... I am talking about being able to define sub mysub :MyAttr { ... } and then be able to hook into the 'MyAttr' attribute
[15:50] <alnewkirk> vs, why?
[15:51] <vs> I'd like to use it for debug/introspection... but I really just want to be able t use it for any purposes that one would use attributes in any other regulat packages...
[15:51] <vs> just wanting to understand why it seems to be different for DBIC..
[15:52] <vs> is it related to class:c3  stuff?
[16:04] <vs> Because it does work with MooseX::NonMoose/extends 'DBIx::Class', but does not work with use base 'DBIx::Class' ... I don't want to have to load Moose on my DBIC classes if I don't have to because of the extra overhead
[16:05] * siracusa (~siracusa@pool-96-233-50-4.bstnma.fios.verizon.net) has joined #dbix-class
[16:32] <@Caelum> vs: you need to put the ->load_components call into a BEGIN {} block
[16:32] <@Caelum> ner0x: the difference between has_one and belongs_to, is that belongs_to defines a foreign key on deploy
[16:32] <@Caelum> ner0x: so if you want a foreign key, use belongs_to
[16:32] <vs> Caelum: I did that
[16:33] <@Caelum> vs: still didn't work?
[16:33] <purl> Maybe you should change the code!  Or your definition of "works". or like not good or nun violence never pays
[16:33] <vs> I tried that, and use base qw(MyAttrClass DBIx::Class) and neither work
[16:34] <vs> it does work with Sub::Attribute
[16:35] <vs> It doesn't throw errors about invalid CODE attributes, but the handle code never gets called...
[16:35] <@Caelum> so if you load your base class at runtime, it works, but at compile time it doesn't
[16:36] <vs> I can only get it to work if I put the atttribute definitions in the package directly
[16:36] <@Caelum> try: require base; base->import('DBIx::Class');
[16:36] <@Caelum> that would be the equivalent of the Moose "extends"
[16:37] <vs> aha... ok, let me try that... 
[16:38] <vs> yep, that works!
[16:38] <@Caelum> bonus points if you can figure out why and submit the appropriate RT tickets :)
[16:39] <vs> I've been beating my head against this for hours... it reminds me how much I still don't know about perl...
[16:41] <vs> but if I can figure it out, I'll send the feedback!
[16:41] <@Caelum> I think there was a MODIFY_CODE_ATTRIBUTES method in DBIx/Class.pm
[16:41] <@Caelum> I don't know why it's there
[16:42] <vs> yep, I know there is... because during some of my tests i saw messsages about it being redefined
[16:42] <vs> redefined by DBIx::Class....
[16:42] <vs> I figured it had to be related to the c3 stuff
[16:43] <@Caelum> it isn't
[16:43] <@Caelum> ask ribasushi he probably knows
=cut
# DBIx::Class Component: ties a RapidApp::TableSpec object to
# a Result class for use in configuring various modules that
# consume/use a DBIC Source

use RapidApp::Include qw(sugar perlutil);

use RapidApp::TableSpec;
use RapidApp::DbicAppCombo2;

__PACKAGE__->mk_classdata( 'TableSpec' );
__PACKAGE__->mk_classdata( 'TableSpec_rel_columns' );

__PACKAGE__->mk_classdata( 'TableSpec_cnf' );
__PACKAGE__->mk_classdata( 'TableSpec_built_cnf' );

# See default profile definitions in RapidApp::TableSpec::Column
my $default_data_type_profiles = {
	text 			=> [ 'bigtext' ],
	blob 			=> [ 'bigtext' ],
	varchar 		=> [ 'text' ],
	char 			=> [ 'text' ],
	float			=> [ 'number' ],
	integer		=> [ 'number', 'int' ],
	tinyint		=> [ 'number', 'int' ],
	mediumint	=> [ 'number', 'int' ],
	bigint		=> [ 'number', 'int' ],
	datetime		=> [ 'datetime' ],
	timestamp	=> [ 'datetime' ],
};
__PACKAGE__->mk_classdata( 'TableSpec_data_type_profiles' );
__PACKAGE__->TableSpec_data_type_profiles({ %$default_data_type_profiles }); 


sub apply_TableSpec :Debug {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	$self->TableSpec_data_type_profiles(
		%{ $self->TableSpec_data_type_profiles || {} },
		%{ delete $opt{TableSpec_data_type_profiles} }
	) if ($opt{TableSpec_data_type_profiles});
	
	$self->TableSpec($self->create_result_TableSpec($self,%opt));
	
	$self->TableSpec_rel_columns({});
	$self->TableSpec_cnf({});
	$self->TableSpec_built_cnf(undef);
}

sub create_result_TableSpec {
	my $self = shift;
	my $ResultClass = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $TableSpec = RapidApp::TableSpec->new( 
		name => $ResultClass->table,
		%opt
	);
	
	my $data_types = $self->TableSpec_data_type_profiles;
	
	foreach my $col ($ResultClass->columns) {
		my $info = $ResultClass->column_info($col);
		my @profiles = ();
		
		push @profiles, $info->{is_nullable} ? 'nullable' : 'notnull';
		
		my $type_profile = $data_types->{$info->{data_type}} || ['text'];
		$type_profile = [ $type_profile ] unless (ref $type_profile);
		push @profiles, @$type_profile; 
		
		$TableSpec->add_columns( { name => $col, profiles => \@profiles } ); 
	}
	
	return $TableSpec;
}


sub TableSpec_valid_db_columns :Debug {
	my $self = shift;

	my @cols = $self->columns;
	
	return @cols;
	
	
	## FIXME: This goes recursive:
	
	my @rels = grep { $self->relationship_info($_)->{attrs}->{accessor} eq 'single' } $self->relationships;
	
	
	foreach my $rel (@rels) {
		scream($rel);
		my $displayField = $self->TableSpec_related_get_conf($rel,'display_column') or next;
		
		push @cols,$rel;
		
		#my $width = $class->TableSpec_related_get_conf($rel
		
		scream($rel,$displayField);
		
		#$self->add_relationship_columns( $rel,
		
		
		#);
	
	}
	
	#scream($self->relationships);
	
	return @cols;
}



sub TableSpec_add_columns_from_related {
	my $self = shift;
	my $rels = get_mixed_hash_args(@_);
	
	foreach my $rel (keys %$rels) {
		my $conf = $rels->{$rel};
		$conf = {} unless (ref($conf) eq 'HASH');
		
		$conf = { %{ $self->TableSpec->default_column_properties }, %$conf } if ( $self->TableSpec->default_column_properties );
		
		$conf->{column_property_transforms}->{name} = sub { $rel . '_' . $_ };
		
		# If its a relationship column that will setup a combo:
		$conf->{column_property_transforms} = { %{$conf->{column_property_transforms}},
			key_col => sub { $rel . '_' . $_ },
			render_col => sub { $rel . '_' . $_ },
		};
		
		my $info = $self->relationship_info($rel) or next;
		
		# Make sure the related class is already loaded:
		eval 'use ' . $info->{class};
		die $@ if ($@);
		
		my $TableSpec = $info->{class}->TableSpec->copy($conf) or next;
		
		my @added = $self->TableSpec->add_columns_from_TableSpec($TableSpec);
		foreach my $Column (@added) {
			$self->TableSpec_rel_columns->{$rel} = [] unless ($self->TableSpec_rel_columns->{$rel});
			push @{$self->TableSpec_rel_columns->{$rel}}, $Column->name;
			
			# Add a new global_init_coderef entry if this column has one:
			rapidapp_add_global_init_coderef( sub { $Column->call_rapidapp_init_coderef(@_) } ) 
				if ($Column->rapidapp_init_coderef);
		}
	}
}


sub TableSpec_add_relationship_columns {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	
	# Moved to TableSpec::Role::DBIC
	#return;
	
	
	
	my $rels = \%opt;
	
	foreach my $rel (keys %$rels) {
		my $conf = $rels->{$rel};
		$conf = {} unless (ref($conf) eq 'HASH');
		
		$conf = { %{ $self->TableSpec->default_column_properties }, %$conf } if ( $self->TableSpec->default_column_properties );
		
		die "displayField is required" unless (defined $conf->{displayField});
		
		$conf->{render_col} = $rel . '_' . $conf->{displayField} unless ($conf->{render_col});
		
		my $info = $self->relationship_info($rel) or die "Relationship '$rel' not found.";
		
		$conf->{foreign_col} = $self->get_foreign_column_from_cond($info->{cond});
		$conf->{valueField} = $conf->{foreign_col} unless (defined $conf->{valueField});
		$conf->{key_col} = $rel . '_' . $conf->{valueField};
		
		#Temporary/initial column setup:
		$self->TableSpec->add_columns({ name => $rel, %$conf });
		my $Column = $self->TableSpec->get_column($rel);
		
		#$self->TableSpec_rel_columns->{$rel} = [] unless ($self->TableSpec_rel_columns->{$rel});
		#push @{$self->TableSpec_rel_columns->{$rel}}, $Column->name;
		
		# Temp placeholder:
		$Column->set_properties({ editor => 'relationship_column' });
		
		my $ResultClass = $self;
		
		$Column->rapidapp_init_coderef( sub {
			my $self = shift;
			
			my $rootModule = shift;
			$rootModule->apply_init_modules( tablespec => 'RapidApp::AppBase' ) 
				unless ( $rootModule->has_module('tablespec') );
			
			my $TableSpecModule = $rootModule->Module('tablespec');
			my $c = RapidApp::ScopedGlobals->get('catalystClass');
			my $Source = $c->model('DB')->source($info->{source});
			
			my $valueField = $self->get_property('valueField');
			my $displayField = $self->get_property('displayField');
			my $key_col = $self->get_property('key_col');
			my $render_col = $self->get_property('render_col');
			my $auto_editor_type = $self->get_property('auto_editor_type');
			my $rs_condition = $self->get_property('ResultSet_condition') || {};
			my $rs_attr = $self->get_property('ResultSet_attr') || {};
			
			my $editor = $self->get_property('editor') || {};
			
			my $column_params = {
				required_fetch_columns => [ 
					$key_col,
					$render_col
				],
				
				read_raw_munger => RapidApp::Handler->new( code => sub {
					my $rows = (shift)->{rows};
					$rows = [ $rows ] unless (ref($rows) eq 'ARRAY');
					foreach my $row (@$rows) {
						$row->{$self->name} = $row->{$key_col};
					}
				}),
				update_munger => RapidApp::Handler->new( code => sub {
					my $rows = shift;
					$rows = [ $rows ] unless (ref($rows) eq 'ARRAY');
					foreach my $row (@$rows) {
						if ($row->{$self->name}) {
							$row->{$key_col} = $row->{$self->name};
							delete $row->{$self->name};
						}
					}
				}),
				no_quick_search => \1,
				no_multifilter => \1
			};
			
			$column_params->{renderer} = jsfunc(
				'function(value, metaData, record, rowIndex, colIndex, store) {' .
					'return record.data["' . $render_col . '"];' .
				'}', $self->get_property('renderer')
			);
			
			# If editor is no longer set to the temp value 'relationship_column' previously set,
			# it means something else has set the editor, so we don't overwrite it:
			if ($editor eq 'relationship_column') {
				if ($auto_editor_type eq 'combo') {
				
					my $module_name = $ResultClass->table . '_' . $self->name;
					$TableSpecModule->apply_init_modules(
						$module_name => {
							class	=> 'RapidApp::DbicAppCombo2',
							params	=> {
								valueField		=> $valueField,
								displayField	=> $displayField,
								name				=> $self->name,
								ResultSet		=> $Source->resultset,
								RS_condition	=> $rs_condition,
								RS_attr			=> $rs_attr,
								record_pk		=> $valueField
							}
						}
					);
					my $Module = $TableSpecModule->Module($module_name);
					
					# -- vv -- This is required in order to get all of the params applied
					$Module->call_ONREQUEST_handlers;
					$Module->DataStore->call_ONREQUEST_handlers;
					# -- ^^ --
					
					$column_params->{editor} = { %{ $Module->content }, %$editor };
				}
			}
			
			$self->set_properties({ %$column_params });
		});
		
		# This coderef gets called later, after the RapidApp
		# Root Module has been loaded.
		rapidapp_add_global_init_coderef( sub { $Column->call_rapidapp_init_coderef(@_) } );
	}
}


sub related_TableSpec {
	my $self = shift;
	my $rel = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $info = $self->relationship_info($rel) or die "Relationship '$rel' not found.";
	my $class = $info->{class};
	
	# Manually load and initialize the TableSpec component if it's missing from the
	# related result class:
	unless($class->can('TableSpec')) {
		$class->load_components('+RapidApp::DBIC::Component::TableSpec');
		$class->apply_TableSpec(%opt);
	}
	
	return $class->TableSpec;
}



# TODO: Find a better way to handle this. Is there a real API
# in DBIC to find this information?
sub get_foreign_column_from_cond {
	my $self = shift;
	my $cond = shift;
	
	die "currently only single-key hashref conditions are supported" unless (
		ref($cond) eq 'HASH' and
		scalar keys %$cond == 1
	);
	
	foreach my $i (%$cond) {
		my ($side,$col) = split(/\./,$i);
		return $col if (defined $col and $side eq 'foreign');
	}
	
	die "Failed to find forein column from condition: " . Dumper($cond);
}


sub get_built_Cnf {
	my $self = shift;
	
	$self->TableSpec_build_cnf unless ($self->TableSpec_built_cnf);
	return $self->TableSpec_built_cnf;
}

sub TableSpec_build_cnf {
	my $self = shift;
	my %set_cnf = %{ $self->TableSpec_cnf || {} };
	$self->TableSpec_built_cnf($self->default_TableSpec_cnf(\%set_cnf));
}

sub default_TableSpec_cnf  {
	my $self = shift;
	my $set = shift || {};

	my $data = $set->{data} || {};
	my $order = $set->{order} || {};
	my $deref = $set->{deref} || {};

	my %defaults = ();
	$defaults{iconCls} = $data->{singleIconCls} if ($data->{singleIconCls} and ! $data->{iconCls});
	$defaults{iconCls} = $defaults{iconCls} || $data->{iconCls} || 'icon-application-view-detail';
	$defaults{multiIconCls} = $data->{multiIconCls} || 'icon-database_table';
	$defaults{singleIconCls} = $data->{singleIconCls} || $defaults{iconCls};
	$defaults{title} = $data->{title} || $self->table;
	$defaults{title_multi} = $data->{title_multi} || $defaults{title};
	($defaults{display_column}) = $self->primary_columns;
	
	my @display_columns = $data->{display_column} ? ( $data->{display_column} ) : $self->primary_columns;

	# row_display coderef overrides display_column to provide finer grained display control
	my $orig_row_display = $data->{row_display} || sub {
		my $record = $_;
		my $title = join('/',map { $record->{$_} || '' } @display_columns);
		$title = sprintf('%.13s',$title) . '...' if (length $title > 13);
		return $title;
	};
	
	$defaults{row_display} = sub {
		my $display = $orig_row_display->(@_);
		return $display if (ref $display);
		return {
			title => $display,
			iconCls => $defaults{singleIconCls}
		};
	};
	
	my $rel_trans = {};
	
	#foreach my $rel ( $class->storage->schema->source($class)->relationships ) {
	#	my $info = $class->relationship_info($rel);
	#	$rel_trans->{$rel}->{editor} = sub {''} unless ($info->{attr}->{accessor} eq 'single');
	#}
	$defaults{related_column_property_transforms} = $rel_trans;
	
	my $defs = { data => \%defaults };
	
	my $col_cnf = $self->default_TableSpec_cnf_columns($set);
	$defs = merge($defs,$col_cnf);

	return merge($defs, $set);
}

sub default_TableSpec_cnf_columns {
	my $self = shift;
	my $set = shift || {};

	my $data = $set->{data} || {};
	my $order = $set->{order} || {};
	my $deref = $set->{deref} || {};
	
	my @col_order = $self->default_TableSpec_cnf_column_order($set);
	my $cols = { map { $_ => {} } @col_order };

	$cols = merge($cols,$set->{data}->{column_properties_ordered} || {});
		
	# higher precidence:
	$cols = merge($cols,$set->{data}->{column_properties} || {});

	my $data_types = $self->TableSpec_data_type_profiles;
	
	foreach my $col (keys %$cols) {
		my $info = $self->column_info($col);
		my @profiles = ();
			
		push @profiles, $info->{is_nullable} ? 'nullable' : 'notnull';
		
		my $type_profile = $data_types->{$info->{data_type}} || ['text'];
		$type_profile = [ $type_profile ] unless (ref $type_profile);
		push @profiles, @$type_profile;
		
		$cols->{$col}->{profiles} = [ $cols->{$col}->{profiles} ] if (
			defined $cols->{$col}->{profiles} and 
			not ref $cols->{$col}->{profiles}
		);
		push @profiles, @{$cols->{$col}->{profiles}} if ($cols->{$col}->{profiles});
		
		$cols->{$col}->{profiles} = \@profiles
	}
	
	return {
		data => { columns => $cols },
		order => { columns => \@col_order }
	};
}


sub default_TableSpec_cnf_column_order :Debug {
	my $self = shift;
	my $set = shift || {};
	
	my @order = ();
	push @order, @{ $self->TableSpec_get_conf('column_properties_ordered',$set) || [] };
	#push @order, $self->columns;
	push @order, $self->TableSpec_valid_db_columns; # <-- native dbic column order has precidence over the column_properties order
	push @order, @{ $self->TableSpec_get_conf('column_properties',$set) || [] };
		
	# fold together removing duplicates:
	@order = uniq @order;
	
	my $ovrs = $self->TableSpec_get_conf('column_order_overrides',$set) or return @order;
	foreach my $ord (@$ovrs) {
		my ($offset,$cols) = @$ord;
		my %colmap = map { $_ => 1 } @$cols;
		# remove colnames to be ordered differently:
		@order = grep { !$colmap{$_} } @order;
		
		# If the offset is a column name prefixed with + (after) or - (before)
		$offset =~ s/^([\+\-])//;
		if($1) {
			my $i = 0;
			my $ndx = 0; # <-- default before (will become 0 below)
			$ndx = scalar @order if ($1 eq '+'); # <-- default after
			for my $col (@order) {
				$ndx = $i and last if ($col eq $offset);
				$i++;
			}
			$ndx++ if ($1 eq '+' and $ndx > 0);
			$offset = $ndx;
		}

		$offset = scalar @order if ($offset > scalar @order);
		splice(@order,$offset,0,@$cols);
	}
	
	return uniq @order;
}


# List of specific param names that we know should be hash confs:
my %hash_conf_params = map {$_=>1} qw(
column_properties
column_properties_ordered
relationship_columns
related_column_property_transforms
column_order_overrides
);

sub TableSpec_set_conf {
	my $self = shift;
	my $param = shift || return undef;
	my $value = shift || die "TableSpec_set_conf(): missing value for param '$param'";
	
	$self->TableSpec_built_cnf(undef);
	
	return $self->TableSpec_set_hash_conf($param,$value,@_) 
		if($hash_conf_params{$param} and @_ > 0);
		
	$self->TableSpec_cnf->{data}->{$param} = $value;
	delete $self->TableSpec_cnf->{order}->{$param};
	
	return $self->TableSpec_set_conf(@_) if (@_ > 0);
	return 1;
}

# Stores arbitrary hashes, preserving their order
sub TableSpec_set_hash_conf {
	my $self = shift;
	my $param = shift;
	
	return $self->TableSpec_set_conf($param,@_) if (@_ == 1); 
	
	$self->TableSpec_built_cnf(undef);
	
	my %opt = get_mixed_hash_args_ordered(@_);
	
	my $i = 0;
	my $order = [ grep { ++$i & 1 } @_ ]; #<--get odd elements (keys)
	
	my $data = \%opt;
	
	$self->TableSpec_cnf->{data}->{$param} = $data;
	$self->TableSpec_cnf->{order}->{$param} = $order;
}

# Sets a reference value with flag to dereference on TableSpec_get_conf
sub TableSpec_set_deref_conf {
	my $self = shift;
	my $param = shift || return undef;
	my $value = shift || die "TableSpec_set_deref_conf(): missing value for param '$param'";
	die "TableSpec_set_deref_conf(): value must be a SCALAR, HASH, or ARRAY ref" unless (
		ref($value) eq 'HASH' or
		ref($value) eq 'ARRAY' or
		ref($value) eq 'SCALAR'
	);
	
	$self->TableSpec_cnf->{deref}->{$param} = 1;
	my $ret = $self->TableSpec_set_conf($param,$value);

	return $self->TableSpec_set_deref_conf(@_) if (@_ > 0);
	return $ret;
}

sub TableSpec_get_conf {
	my $self = shift;
	my $param = shift || return undef;
	my $storage = shift || $self->get_built_Cnf;
	
	return $self->TableSpec_get_hash_conf($param,$storage) if ($storage->{order}->{$param});
	
	my $data = $storage->{data}->{$param};
	return deref($data) if ($storage->{deref}->{$param});
	return $data;
}

sub TableSpec_get_hash_conf {
	my $self = shift;
	my $param = shift || return undef;
	my $storage = shift || $self->get_built_Cnf;
	
	my $data = $storage->{data}->{$param};
	my $order = $storage->{order}->{$param};
	
	ref($data) eq 'HASH' or
		die "FATAL: Unexpected data! '$param' has a stored order, but it's data is not a HashRef!";
		
	ref($order) eq 'ARRAY' or
		die "FATAL: Unexpected data! '$param' order is not an ArrayRef!";
		
	my %order_indx = map {$_=>1} @$order;
	
	!$order_indx{$_} and
		die "FATAL: Unexpected data! param '$param' - found key '$_' missing from stored order!"
			for (keys %$data);
			
	!$data->{$_} and
		die "FATAL: Unexpected data! param '$param' - missing declared ordered key '$_' from data!"
			for (@$order);
	
	return map { $_ => $data->{$_} } @$order;
}

sub TableSpec_has_conf {
	my $self = shift;
	my $param = shift;
	my $storage = shift || $self->get_built_Cnf;
	return 1 if (exists $storage->{data}->{$param});
	return 0;
}

# Gets a TableSpec conf param, if exists, from a related Result Class
sub TableSpec_related_get_conf {
	my $self = shift;
	my $rel = shift || return undef;
	my $param = shift || return undef;
	
	my $info = $self->relationship_info($rel) || return undef;
	my $relclass = $info->{class};
	#my $relclass = $self->related_class($rel) || return undef;
	$relclass->can('TableSpec_get_conf') || return undef;
	return $relclass->TableSpec_get_conf($param);
}

=pod
sub TableSpec_set_conf_column_order {
	my $self = shift;
	my $offset = $_[0];
	die "TableSpec_set_column_order(): expected offset/index number in first arg (got '$offset')" unless (
		defined $offset and
		$offset =~ /^\d+$/
	);
	return $self->TableSpec_set_conf_column_order_base(@_);
}

# Like TableSpec_set_conf_column_order but the offset is the name of another column
sub TableSpec_set_conf_column_order_after {
	my $self = shift;
	my $colname = shift;
	return $self->TableSpec_set_conf_column_order_base('+' . $colname,@_);
}

# Like TableSpec_set_conf_column_order but the offset is the name of another column
sub TableSpec_set_conf_column_order_before {
	my $self = shift;
	my $colname = shift;
	return $self->TableSpec_set_conf_column_order_base('-' . $colname,@_);
}

# Can be called over and over again to apply and re-apply
sub TableSpec_set_conf_column_order_base {
	my $self = shift;
	my $offset = shift;
	my @cols = @_;
	@cols = $_[0] if (ref($_[0]));
	die "TableSpec_set_column_order(): no column names supplied" unless (@cols > 0);
	
	$self->TableSpec_cnf->{column_order_overrides}->{data} = [] 
		unless ($self->TableSpec_cnf->{column_order_overrides}->{data});
		
	push @{$self->TableSpec_cnf->{column_order_overrides}->{data}}, [$offset,\@cols];
}
=cut

1;
