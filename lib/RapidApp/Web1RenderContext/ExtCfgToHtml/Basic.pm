package RapidApp::Web1RenderContext::ExtCfgToHtml::Basic;
use Moose::Role;

sub render_xtype_panel {
	my ($self, $renderCxt, $cfg)= @_;
	
	$renderCxt->incCSS('/static/rapidapp/css/web1_ExtJSBasic.css');
	
	$renderCxt->write('<div class="xt-panel">');
	# make sure we have items to render
	my $items= ref $cfg->{items} eq 'ARRAY'? $cfg->{items} : defined $cfg->{items}? [ $cfg->{items} ] : []; # items is allowed to be a single item
	if (scalar(@$items)) {
		# build the completed list of items
		my %defaults= defined $cfg->{defaults}? %{$cfg->{defaults}} : ();
		my $fullItems= [ map { {%defaults, %$_} } @$items ];
		
		my $layout= $cfg->{layout} || "box";
		my $layoutFn= $self->can("render_layout_$layout") || \&render_layout_box;
		
		$self->$layoutFn($renderCxt, $fullItems);
	}
	$renderCxt->write('</div>');
}

sub render_layout_box {
	my ($self, $renderCxt, $items)= @_;
	$renderCxt->write('<div class="ly-box">');
	for my $item (@$items) {
		$self->renderAsHtml($renderCxt, $item);
	}
	$renderCxt->write('</div>');
}

sub render_layout_anchor {
	my ($self, $renderCxt, $items)= @_;
	render_layout_box(@_); # temporary
}

sub render_layout_hbox {
	my ($self, $renderCxt, $items)= @_;
	$renderCxt->write('<table class="ly-hbox"><tr>');
	for my $item (@$items) {
		$renderCxt->write('<td>');
		$self->renderAsHtml($renderCxt, $item);
		$renderCxt->write('</td>');
	}
	$renderCxt->write('</tr></table>');
}

sub render_xtype_spacer {
	my ($self, $renderCxt, $cfg)= @_;
	my ($w, $h)= ($cfg->{width}, $cfg->{height});
	$renderCxt->write('<div style="'.($w? "width:$w;":'').($h? "height:$h;":'').'"> </div>');
}

sub render_xtype_htmleditor {
	my ($self, $renderCxt, $cfg)= @_;
	$renderCxt->write($cfg->{value});
}

no Moose;
1;
