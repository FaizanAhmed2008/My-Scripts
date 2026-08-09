import os

msg = input("Commit : ")

os.system("git add .")
os.system(f'git commit -m "{msg}"')
os.system("git push origin main")