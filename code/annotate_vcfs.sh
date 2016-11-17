#!/bin/bash
# set -x

## USAGE: annotate_vcfs.sh output/run_dir

## Description: This script will find all VCF files in your Run dir and annotate them with ANNOVAR
## This script is set up to use Ion Torrent 5.0 VCF's
 
# ~~~~~~ script args ~~~~~~ #
input_dir="$1"


# ~~~~~~ parameters ~~~~~~ #

# ANNOVAR version: 
# Version: $Date: 2015-06-17 21:43:53 -0700 (Wed, 17 Jun 2015) $
build_version="hg19"
annovar_db_dir="$(readlink -f bin/annovar/db)"
convert2annovar_bin="$(readlink -f bin/annovar/convert2annovar.pl)"
table_annovar_bin="$(readlink -f bin/annovar/table_annovar.pl)"
annovar_protocol="-protocol refGene,cosmic68,clinvar_20150629,1000g2015aug_all -operation g,f,f,f"

# bcftools-1.3.1
bcftools_bin="$(readlink -f bin/bcftools)"

vcf2tsv_bin="$(readlink -f bin/vcf2tsv)"
# ~~~~~~~~~~~~ # 


# ~~~~~~~~~~~~ # find VCF files # ~~~~~~~~~~~~ # 
vcf_files="$(find "$input_dir" -type f -name "*.vcf")"


# ~~~~~~~~~~~~ # Annotate with ANNOVAR # ~~~~~~~~~~~~ # 
for i in $vcf_files; do 
# vcf_input="$(basename $i)"
vcf_input="$i"
file_dir="$(dirname $i)"
barcode_ID="$(basename $(dirname $i))"
avinput_file="${file_dir}/${barcode_ID}.avinput"
avoutput_file="${avinput_file%%.avinput}"
# (
    # convert the VCF to ANNOVAR input format
    if [ -f $vcf_input ]; then 
        [ ! -f $avinput_file ] && $convert2annovar_bin -format vcf4old "$vcf_input" -includeinfo > "$avinput_file"
    else
        echo -e "ERROR: VCF input file not found:\n$vcf_input"
        echo "Exiting.."
        exit
    fi
    # run ANNOVAR on the avinput
    if [ -f $avinput_file ]; then
        [ ! -f ${avoutput_file}.hg19_multianno.txt ] && $table_annovar_bin "$avinput_file" "$annovar_db_dir" -buildver "$build_version" -out "$avoutput_file" -remove $annovar_protocol -nastring .
    else
        echo -e "ERROR: AVINPUT file not found:\n${avinput_file}"
        echo "Exiting.."
        exit
    fi
# ) # & 
done

# ~~~~~~~~~~~~ # Query VCF for fields # ~~~~~~~~~~~~ # 
for i in $vcf_files; do 
file_dir="$(dirname $i)"
barcode_ID="$(basename $(dirname $i))"
vcf_input="$i"
query_output_file="${file_dir}/${barcode_ID}_query.tsv"
# (
    if [ -f $vcf_input ]; then 
        echo -e "Running bcftools on:\n${i}\nOutputting to:\n${query_output_file}\n"
        echo -e 'You can probably ignore "contig is not defined in the header" messages...'
        echo -e "Chrom\tPosition\tRef\tVariant\tQuality\tFrequency\tCoverage\tAllele Coverage\tStrand Bias" > "$query_output_file"
        $bcftools_bin query -f '%CHROM\t%POS\t%REF\t%ALT\t%QUAL\t%AF\t%FDP\t%FAO\t%STB\n' "$vcf_input" >> "$query_output_file"
        # sanity tests
        [ ! -f $query_output_file ] && echo -e "ERROR: File not created properly:\n${query_output_file}\nExiting.." && exit
        query_len="$(tail -n +2 ${query_output_file} | wc -l)"; # echo "query_len is $query_len"
        vcf_len="$(cat $vcf_input | grep -Ev '^#' | wc -l)"; # echo "vcf_len is $vcf_len"
        [ ! $query_len -eq $vcf_len ] && echo 'ERROR: number of variants in TSV does not match VCF, EXITING' && exit
    else
        echo -e "ERROR: VCF input file not found:\n$i"
        echo "Exiting.."
        exit
    fi
# )
done

# ~~~~~~~~~~~~ # Convert VCF to TSV # ~~~~~~~~~~~~ # 
for i in $vcf_files; do 
file_dir="$(dirname $i)"
barcode_ID="$(basename $(dirname $i))"
vcf_input="$i"
tsv_output_file="${file_dir}/${barcode_ID}.tsv"
# (
    if [ -f $vcf_input ]; then 
        echo -e "Converting VCF to TSV:\n${vcf_input}\n${tsv_output_file}\n"
        $vcf2tsv_bin "$vcf_input" > "$tsv_output_file"
        [ ! -f $tsv_output_file ] && echo -e "ERROR: TSV file not created properly;\n${tsv_output_file}" && exit
        tsv_len="$(tail -n +2 ${tsv_output_file} | wc -l)"; # echo "tsv_len is $tsv_len"
        vcf_len="$(cat $vcf_input | grep -Ev '^#' | wc -l)"; # echo "vcf_len is $vcf_len"
        [ ! $tsv_len -eq $vcf_len ] && echo 'ERROR: number of variants in TSV does not match VCF, EXITING' && exit
    else
        echo -e "ERROR: VCF input file not found:\n$vcf_input"
        echo "Exiting.."
        exit
    fi
# )
done

# delete the stuff we just made.. 
# find output/R_2016_09_01_14_26_55_user_SN2-192-IT16-039-1/ -type f -path "*variantCaller_out.*" -name "IonXpress*" -name "*.tsv" -exec rm -f {} \;