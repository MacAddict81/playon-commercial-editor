#!/usr/bin/env bash
#Script To Remove Commercials From PlayOn.TV Recordings Using Chapter Markers

#Current Working Directory
readonly work="$(cd "$(dirname "$0")" && pwd)"
#Queue Of Files To Be Processed
readonly queue="$work/queue.txt"

#Load Initial File From Queue
input="$(sed -n 1p "$queue")"

#Begin Main Loop
while [ "$input" ]; do
    #Extract Title Name From Input
    title_name="$(basename "$input" | sed 's/\.[^.]*$//')"
    #Output A Separator With Title
    echo ">>>------------------>" 2>&1 | tee log.txt
    echo ">>>------> Processing $title_name <------<<<" 2>&1 | tee -a log.txt
    echo ">>>------------------>" 2>&1 | tee -a log.txt
    #Remux Input MP4 To Temp MKV
    mkvmerge -o "Temp-00.mkv" "$input" 2>&1 | tee -a log.txt
    #Extract Chapters To "chapters.txt" File
    mkvextract "Temp-00.mkv" chapters --simple chapters.txt 2>&1 | tee -a log.txt
    #And Test If There Are Any Chapters To Cut
    if [ -e "chapters.txt" ]; then
        echo "--------------------------------------" 2>&1 | tee -a log.txt
        echo "| CHAPTER MARKERS ... SLICE AND DICE |" 2>&1 | tee -a log.txt
        echo "-------------------------------------" 2>&1 | tee -a log.txt
        #Select "Video" Titled Chapters For Saving And Output To "save.txt"
        grep Video chapters.txt > save.txt
        #Split Temp MKV File By Chapters
        mkvmerge -o "Temp-%02d.mkv" --split chapters:all "Temp-00.mkv" 2>&1 | tee -a log.txt
        #Get First Selected Chapter From "save.txt"
        chapter_number="$(sed -n 1p "save.txt")"
        chapter_number="${chapter_number:7:2}"
        #Build Chapter Selection String From Selected Chapters
        while [ "$chapter_number" ]; do
            #Append Selection String To Itself
            selection_string="$selection_string Temp-$chapter_number.mkv "
            #Remove Top Line From "save.txt" And Exit Loop If Last Line Deleted
            sed -i '' 1d "save.txt" || break
            #Get Next Selected Chapter From "save.txt"
            chapter_number="$(sed -n 1p "save.txt")"
            chapter_number="${chapter_number:7:2}"
        done
        #Merge The Selected Chapter Files Into Final Output
        mkvmerge -o "$input.mkv" '[' $selection_string ']' 2>&1 | tee -a log.txt
    else
        echo "---------------------------------" 2>&1 | tee -a log.txt
        echo "| NO CHAPTERS ... NOTHING TO DO |" 2>&1 | tee -a log.txt
        echo "---------------------------------" 2>&1 | tee -a log.txt
        #Nothing To Cut So Preserve Original
        mkvmerge -o "$input.mkv" "Temp-00.mkv" 2>&1 | tee -a log.txt
    fi
    #Clean Up After This Run By Removing Temp And Working Files
    rm Temp-*.mkv 2>&1 | tee -a log.txt
    rm chapters.txt 2>&1 | tee -a log.txt
    rm save.txt 2>&1 | tee -a log.txt
    mv "log.txt" "$input.mkv.log"
    #Remove Top Entry From Queue And Exit Script If Last Line Deleted
    sed -i '' 1d "$queue" || exit 1
    #Get Next File To Be Processed From The Queue
    input="$(sed -n 1p "$queue")"
    #Blank Selection String For Next Iteration (Otherwise Larger And Larger Files Created)
    selection_string=''
done