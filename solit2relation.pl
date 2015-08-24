#use utf8;
use Encode;
use Data::Dumper;
use Text::MeCab;
use Web::Scraper;
use Try::Tiny;
use URI;
use Text::CSV_XS;
use Getopt::Long qw/:config posix_default no_ignore_case bundling auto_help/;

my $opt = +{};
GetOptions($opt, qw/filename|f=s/);

my $out_csv;

my $in_csv = Text::CSV_XS->new({binary=>1});
my $in_fh;
open $in_fh, "<",$opt->{filename} or die "fail to read file";

$in_csv->getline($in_fh);
while (my $in_row = $in_csv->getline($in_fh)) {
     # ScreenName,"フォロワー数","フォロー数","投稿日時","本文","検索ワード",URL

     my $out_row = $in_row->[3] . "," .  $in_row->[0];
     my @words = &_get($in_row->[4],30);
     for (@words) {
         $out_row .= "," . encode('Shift_JIS',decode_utf8($_->{value}));
     }
     $out_csv .= $out_row . "\n";
}

close $in_fh;

# CSVファイル書き出し

open $out_fh, ">", "solit2relation.csv";
print $out_fh $out_csv;
close $out_fh;

sub _get {
    my ($input, $num_of_last) = @_;
    $num_of_last = 10 unless $num_of_last;
   
    my $parser = Text::MeCab->new();
    my $encoding = Encode::find_encoding( Text::MeCab::ENCODING );

    my $node = $parser->parse($input);
    my %count;

    while ($node = $node->next) {
        # 名詞を含む　かつ　非自立、接尾、数を含まない
        if ($node->feature =~ /\xe5\x90\x8d\xe8\xa9\x9e/g and $node->feature !~ /\xE9\x9D\x9E\xE8\x87\xAA\xE7\xAB\x8B|\xE6\x8E\xA5\xE5\xB0\xBE|\xE6\x95\xB0/g) {
            $count{$node->surface}++;
#print $node->surface .":". $node->feature . "\n";
        }
    }

    my @sorted;
    my $rank = 1;
    for my $key (sort { $count{$b} <=> $count{$a} || $a cmp $b } keys %count) {
        last if $rank > $num_of_last;
        push @sorted,{rank=>$rank++, value=>$key, count=>$count{$key}}; 
    }

    return @sorted;
}

1;
