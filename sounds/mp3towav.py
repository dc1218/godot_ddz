import os
import subprocess

def batch_mp3_to_wav(folder: str = ".", sr=24000, mono=True):
    """当前目录所有 .mp3 批量转同名 wav"""
    for fname in os.listdir(folder):
        if fname.lower().endswith(".mp3"):
            mp3_path = os.path.join(folder, fname)
            base, _ = os.path.splitext(fname)
            wav_name = base + ".wav"
            wav_path = os.path.join(folder, wav_name)

            cmd = [
                "ffmpeg",
                "-y",
                "-i", mp3_path,
                "-c:a", "pcm_s16le",
                "-ar", str(sr),
                "-ac", "1" if mono else "2",
                wav_path
            ]
            print(f"转换: {fname} → {wav_name}")
            try:
                subprocess.run(cmd, check=True, capture_output=True)
            except subprocess.CalledProcessError as e:
                print(f"❌失败：{fname}，{e}")

if __name__ == "__main__":
    batch_mp3_to_wav()