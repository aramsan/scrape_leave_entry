use utf8;
use Encode;
use Data::Dumper;
use Text::MeCab;
use Web::Scraper;
use Try::Tiny;
use URI;


#my $csv = Text::CSV_XS->new();
my $csv_data;

for my $page (1..69) {

    my $uri = new URI("http://taisyoku.tsunamayo.net/entries?page=$page");

    my $scraper = scraper {
        process ('.entry-main h3  a', 'urls[]' => '@href');
        process ('small span', 'date[]' => 'TEXT');
    };

    try {
        my $blog_scraper = scraper {
            process ('body', 'text' => 'TEXT',);
        };

        my $res = $scraper->scrape($uri);
#print Dumper(@{$res->{urls}})."\n";

        for (my $i = 0; $i <= $#{$res->{urls}}; $i++) {
#print @{$res->{date}}[$i]."\n";
            my $blog_uri = new URI(@{$res->{urls}}[$i]);
            my $blog_res = $blog_scraper->scrape($blog_uri);
#print encode_utf8($blog_res->{text})."\n";
#print Dumper(&get($blog_res->{text}))."\n";
            my @sentencies = split(/。|？/, $blog_res->{text});
            #my @sentencies = split(/\xE3\x80\x82|\xEF\xBC\x9F/, $blog_res->{text});
            for my $sentence (@sentencies) {
#print encode_utf8($sentence)."\n\n\n";
                my @words = &get($sentence,30);
                my $date = @{$res->{date}}[$i];
                $date  =~ s/\-/\//g;
                my $row = $date;
                for (@words) {
                    $row .= "," . encode('Shift_JIS',decode_utf8($_->{value}));
                }
                $csv_data .= $row . "\n";
            }
#print Dumper($row) . "\n";       
        }
    }
    catch {};
}
#print Dumper($csv_data) . "\n";       

# CSVファイル書き出し
open $fh, ">", "leave-sentence.csv";
print $fh $csv_data;
close $fh;


sub get {
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
