# cython: language_level=3, boundscheck=True, wraparound=True
# Note to self: here's how to start a venv:
"""
python3 -m venv venv
source venv/bin/activate
python3 -m pip install -r requirements.txt
"""

import cython
import csv
import tkinter as tk
from tkinter import filedialog as fd
from tkinter import PhotoImage as pi
from tkinter import simpledialog, messagebox, ttk
import psutil
from gpt4all import GPT4All
import json
import gc
import sys
import random
import threading
import pyttsx3
import queue
import re

cdef int modtokens
cdef tuple optimize():
    cdef int physcores = psutil.cpu_count(logical=False)
    cdef int logicores = psutil.cpu_count(logical=True)
    return physcores, logicores

cdef list cmdhistory = []
cdef int poshistory = -1

# token JSON function
cdef int read_tokens_from_json():
    cdef dict data
    try:
        with open("data.json", "r") as f:
            data = json.load(f)
            return data.get("tokens", 96) 
    except FileNotFoundError:
        return 256 
    
modtokens = read_tokens_from_json()

physcores, logicores = optimize()
threads = min(logicores, 8)

print(f"[DEBUG] {threads} threads in use.")

data = {
    "tokens": modtokens
}

system_prompt = '''You are Cyckle, a helpful AI assistant. Your responses should be clear, direct, and relevant to the user's questions. Aim to be informative yet concise.'''

cdef object usermodel
usermodel = GPT4All("Phi-3-mini-4k-instruct.Q4_0.gguf", model_path="models", n_threads=threads)

cdef str sentence_buffer = ""
def stream(token_id, token):
    global sentence_buffer
    response_text.config(state=tk.NORMAL)
    response_text.insert(tk.END, token)
    response_text.config(state=tk.DISABLED)
    response_text.see(tk.END)
    response_text.update_idletasks()

    sentence_buffer += token
    if re.search(r"[.!?]['\")\]]?\s$", sentence_buffer):
        tts_queue.put(sentence_buffer.strip())
        sentence_buffer = ""
    return True

cdef object tts_engine = pyttsx3.init()
tts_engine.setProperty('rate', 150)
tts_engine.setProperty('volume', 0.85)
voices = tts_engine.getProperty('voices')
tts_engine.setProperty('voice', voices[33].id)

cdef str tts_buffer = ""
cdef object tts_lock = threading.Lock()
cdef stop_tts = False
cdef object tts_queue = queue.Queue()

cpdef tts_runner():
    global stop_tts
    while not stop_tts:
        try:
            chunk = tts_queue.get(timeout=1)
            if chunk is None:
                break
            chunk += " ..."

            tts_engine.say(chunk)
            tts_engine.runAndWait()
            tts_engine.stop() 
        except queue.Empty:
            continue
        except Exception as e:
            print(f"[TTS] Error: {e}")

cpdef void handle_input(event=None):
    print(f"[DEBUG] Input registered.")
    global modtokens , cmdhistory, poshistory, usermodel
    cdef str userinput
    userinput = entry.get()

    if userinput.strip():
        cmdhistory.append(userinput)
        poshistory = len(cmdhistory)

    if userinput.lower() == "quit":
        print(f"[DEBUG] User requested to quit.")
        main.quit()
        gc.collect()
        sys.exit(0)
        return

    elif userinput.lower() == "modtokens":
        print(f"[DEBUG] User requested to modify token limit.")
        current_limit = f'Current token limit is set to {modtokens}'
        warning = 'WARNING: HIGHER TOKEN LIMITS MAY CAUSE HIGHER USAGE OF RESOURCES! DO THIS AT YOUR OWN RISK.'
        messagebox.showwarning("Modtokens", f"{current_limit}\n{warning}")
        new_limit = simpledialog.askinteger("Modtokens", "Enter new token limit:")
        if new_limit is not None:
            modtokens = new_limit
            data["tokens"] = modtokens  
            messagebox.showinfo("Modtokens", f"Token limit has been set to {modtokens}")
            filename = "data.json"  
            with open(filename, 'w') as f:
                json.dump(data, f, indent=4)
        else:
            messagebox.showerror("Modtokens", f'The entry "{new_limit}" is not a valid integer. Please try again.')

    else:
        print(f"[AI] Forwarding input to model.")
        label1.config(text="YOU>>> " + userinput)
        response_text.config(state=tk.NORMAL)
        response_text.delete(1.0, tk.END)
        response_text.insert(tk.END, "\n")
        response_text.config(state=tk.DISABLED)
        with usermodel.chat_session(system_prompt=system_prompt):
            response = usermodel.generate(userinput, max_tokens=modtokens, callback=stream, temp=0.3, top_k=25, top_p=0.9, repeat_penalty=1.1, n_batch=8)
            response_text.config(state=tk.NORMAL)
            response_text.delete(1.0, tk.END)
            response_text.insert(tk.END, "Cyckle>>> " + response)
            response_text.config(state=tk.DISABLED)
    entry.delete(0, tk.END)

cpdef void random_placeholder(event):
    global used_placeholder
    placeholders = ["Ask anything", "Quench your wonder", "What's on your mind?", "Your query awaits", "Unleash your curiosity", "Seek information"]
    used_placeholder = random.choice(placeholders)

cpdef entry_focus(event):
    if entry.get() == used_placeholder:
        entry.delete(0, tk.END)
        entry.config(foreground="#ffffff")

cpdef entry_unfocus(event):
    if entry.get() == '':
        entry.insert(0, used_placeholder)
        entry.config(foreground="#D3D3D3")

cpdef void handle_history(event):
    global poshistory
    if event.keysym == "Up":
        if poshistory > 0:
            poshistory -= 1
            entry.delete(0, tk.END)
            entry.insert(0, cmdhistory[poshistory])
    elif event.keysym == "Down":
        if poshistory < len(cmdhistory) - 1:
            poshistory += 1
            entry.delete(0, tk.END)
            entry.insert(0, cmdhistory[poshistory])
        else:
            poshistory = len(cmdhistory)
            entry.delete(0, tk.END)

cpdef void handle_csv(event=None):
    global response_text, main, label1
    main.filename = fd.askopenfilename(initialdir = "/home/",title = "Open CSV/TSV file",filetypes = (("CSV/TSV files","*.csv *.tsv"),("All files","*.*")))
    
    if main.filename.endswith(".tsv"):
        try:
            with open(main.filename, newline='') as tsvfile:
                reader = csv.reader(tsvfile)
                data = [row for row in reader]
                tsv_str = "\n".join([", ".join(row) for row in data])
                response_text.config(state=tk.NORMAL)
                response_text.delete(1.0, tk.END)
                response_text.insert(tk.END, "Analyzing TSV...")
                label1.config(text="TSV>>> " +main.filename)
            with usermodel.chat_session(system_prompt=system_prompt):
                print("[TSV] Generating analysis")
                tsvresponse = usermodel.generate(tsv_str, max_tokens=modtokens, callback=stream, temp=0.2, top_k=25, top_p=0.9, repeat_penalty=1.18, n_batch=8)
                response_text.config(state=tk.NORMAL)
                response_text.delete(1.0, tk.END)
                response_text.insert(tk.END, "Cyckle>>> " + tsvresponse)
                response_text.config(state=tk.DISABLED)
        except Exception as e:
            print(f"[TSV] Failed to read TSV file: {e}")

    if main.filename.endswith(".csv"):
        try:
            with open(main.filename, newline='') as csvfile:
                reader = csv.reader(csvfile)
                data = [row for row in reader]
                csv_str = "\n".join([", ".join(row) for row in data])
                response_text.config(state=tk.NORMAL)
                response_text.delete(1.0, tk.END)
                response_text.insert(tk.END, "Analyzing CSV...")
                label1.config(text="CSV>>> " +main.filename)
            with usermodel.chat_session(system_prompt=system_prompt):
                print("[CSV] Generating analysis")
                csvresponse = usermodel.generate(csv_str, max_tokens=modtokens, callback=stream, temp=0.2, top_k=25, top_p=0.9, repeat_penalty=1.18, n_batch=8)
                response_text.config(state=tk.NORMAL)
                response_text.delete(1.0, tk.END)
                response_text.insert(tk.END, "Cyckle>>> " + csvresponse)
                response_text.config(state=tk.DISABLED)
        except Exception as e:
            print(f"[CSV] Failed to read CSV file: {e}")

root = tk.Tk()
root.withdraw() 

def maingui():
    global main, label1, entry, response_text
    splash.destroy()
    
    main = tk.Toplevel()
    main.config(bg="#092332")
    main.title("Cyckle")
    main.resizable(False, False)

    icon = pi(file="assets/icon.png")
    main.iconphoto(True, icon)

    style = ttk.Style(main)
    style.theme_use("clam")
    style.configure("TButton", background="#1c1c1c", foreground="#ffffff")
    style.configure("TLabel", foreground="#ffffff", background="#092332")
    style.configure("TEntry", foreground="#ffffff", fieldbackground="#092332", background="#092332")

    periodic_redraw()

    # window geometries
    sw = main.winfo_screenwidth()
    sh = main.winfo_screenheight()
    swutil = sw*0.8
    shutil = sh*0.9
    main.geometry(f"{int(swutil)}x{int(shutil)}+50+50")

    # grid config
    main.grid_rowconfigure(0, weight=2)
    main.grid_rowconfigure(1, weight=5)
    main.grid_rowconfigure(2, weight=0)
    main.grid_columnconfigure(0, weight=1)
    main.grid_rowconfigure(0, minsize=50)

    label1 = ttk.Label(master=main, text="YOU>>>", anchor="w")
    label1.config(font=("DejaVu Sans", 20))
    label1.grid(row=0, column=0, sticky="nsew", padx=10, pady=(20, 10))
    main.grid_rowconfigure(0, minsize=70)

    # text label
    response_text = tk.Text(master=main, wrap=tk.WORD, bg="#1c1c1c", fg="#ffffff", font=("DejaVu Sans", 20), relief=tk.FLAT)
    response_text.grid(row=1, column=0, sticky="nsew", padx=10, pady=10)
    response_text.config(state=tk.DISABLED)

    # entry box
    entry = ttk.Entry(master=main, font=("DejaVu Sans", 15))
    entry.grid(row=2, column=0, sticky="ew", padx=10, pady=10)
    random_placeholder(None)
    entry.bind("<Return>", handle_input)
    entry.bind("<FocusIn>", entry_focus)
    entry.bind("<FocusOut>", entry_unfocus)
    entry.bind("<Up>", handle_history)
    entry.bind("<Down>", handle_history)

    # analysis button
    csv_button = ttk.Button(master=main, text="Analyze CSV", command=handle_csv, style="TButton")
    csv_button.grid(row=3, column=0, sticky="ew", padx=10, pady=(10, 10))

    # redraw system
    main.bind("<Map>", lambda e: force_redraw())
    main.bind("<Visibility>", lambda e: force_redraw())

    # me when my code has had undetected memory leaks for 3 months
    main.protocol("WM_DELETE_WINDOW", lambda: (clean_up(), main.destroy()))

    # function calls
    sys_watchdog()
    tts_thread = threading.Thread(target=tts_runner, daemon=True)
    tts_thread.start()

    main.mainloop()

cpdef force_redraw():
    main.update_idletasks()
    main.update()

cpdef periodic_redraw():
    force_redraw()
    main.after(1000, periodic_redraw)

cpdef center_window(win, width, height):
    screen_width = win.winfo_screenwidth()
    screen_height = win.winfo_screenheight()

    x = (screen_width // 2) - (width // 2)
    y = (screen_height // 2) - (height // 2)

    win.geometry(f"{width}x{height}+{x}+{y}")

cpdef clean_up():
    global usermodel, response_text, entry, label1
    try:
        usermodel = None 
    except: pass

    try:
        response_text.destroy()
        entry.destroy()
        label1.destroy()
        main.destroy()
        gc.collect()
        sys.exit(0)
        quit()
        return
    except: pass

cpdef low_mem_warn(mem_warn_mb=1024):
    unalloc_mem = psutil.virtual_memory().available / (1024 ** 2)
    return unalloc_mem < mem_warn_mb

cpdef bint low_mem_crticial(mem_warn_mb=512):
    unalloc_mem = psutil.virtual_memory().available / (1024 ** 2)
    return unalloc_mem < mem_warn_mb

cpdef sys_watchdog():
    if low_mem_warn(1024):
        print(f"[WATCHDOG] Low memory detected, please attempt to free resources outside of the main Cyckle application.")
    if low_mem_crticial(512):
        print(f"[WATCHDOG] Memory is critically low, exiting main Cyckle application.")
        gc.collect()
        sys.exit(1)
    else:
        print(f"[WATCHDOG] Memory is sufficient, continuing operation.")
    main.after(5000, sys_watchdog)

splash = tk.Toplevel()
splash.overrideredirect(True)
center_window(splash, 600, 384)
splashimg = pi(file="assets/splash.png")
 
splash_label = tk.Label(splash, image=splashimg)
splash_label.pack()

# satisfies pip
def main():
    global root, splash
    root.deiconify() 
    splash.after(5000, maingui)
    splash.mainloop()