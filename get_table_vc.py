import re

filepath = 'Sources/PhantomSwift/Modules/MemoryLeak/UI/HeapSnapshotVC.swift'
with open(filepath, 'r') as f:
    content = f.read()

if "PhantomTableVC" in content:
    print("Uses PhantomTableVC")
else:
    print("Does not use PhantomTableVC")
