#!/bin/bash

# A simple Git helper script to automate common tasks

while true; do
    echo "CLI Tool to perform Git operations easily"
    echo "0.Status"
    echo "1.Add Files + Commit + Push"
    echo "2.Commit + Push"
    echo "3.Add File"   
    echo "4.Commit"
    echo "5.Push"
    echo "6.Exit"
    echo ""

    read -p "Enter Your Choice: " choice

    case $choice in
        0)
            git status
            ;;
        1)
            read -p "Enter commit message: " commit_message
            git add .
            git commit -m "$commit_message"
            git push
            break
            ;;
        2)
            read -p "Enter commit message: " commit_message
            git commit -m "$commit_message"
            git push
            break
            ;;
        3)
            read -p "Enter file name to add: " file_name
            git add "$file_name"
            ;;
        4)
            read -p "Enter commit message: " commit_message
            git commit -m "$commit_message"
            ;;
        5)
            git push
            break
            ;;
        6)
            echo "Exiting CLI Tool. Goodbye!"
            break
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
