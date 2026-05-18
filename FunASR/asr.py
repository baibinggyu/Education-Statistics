#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import tempfile
import ffmpeg
from funasr import AutoModel


def extract_audio(video_path: str, audio_path: str) -> bool:
    try:
        (
            ffmpeg
            .input(video_path)
            .output(
                audio_path,
                acodec="pcm_s16le",
                ac=1,
                ar="16000"
            )
            .run(overwrite_output=True, quiet=True)
        )
        return True

    except ffmpeg.Error as e:
        msg = e.stderr.decode("utf-8", errors="ignore") if e.stderr else str(e)
        print(f"ffmpeg extract error: {msg}", file=sys.stderr)
        return False


def format_timestamp(time_value) -> str:
    try:
        t = float(time_value)
    except Exception:
        t = 0.0

    if t > 10000:
        t = t / 1000.0

    if t < 0:
        t = 0.0

    hours = int(t // 3600)
    minutes = int((t % 3600) // 60)
    seconds = int(t % 60)
    millis = int((t - int(t)) * 1000)

    return f"{hours:02d}:{minutes:02d}:{seconds:02d},{millis:03d}"


def parse_asr_result(res):
    subtitles = []

    if not isinstance(res, list) or len(res) == 0:
        return subtitles

    first = res[0]

    if not isinstance(first, dict):
        return subtitles

    sentence_info = first.get("sentence_info", [])

    if isinstance(sentence_info, list) and len(sentence_info) > 0:
        for item in sentence_info:
            if not isinstance(item, dict):
                continue

            text = item.get("text", "")
            start = item.get("start", None)
            end = item.get("end", None)

            if start is None or end is None:
                continue

            if not isinstance(text, str) or not text.strip():
                continue

            try:
                if float(end) <= float(start):
                    continue
            except Exception:
                continue

            subtitles.append((start, end, text.strip()))

        return subtitles

    timestamp_list = first.get("timestamp", [])
    text = first.get("text", "")

    if isinstance(timestamp_list, list) and len(timestamp_list) > 0:
        for item in timestamp_list:
            if not isinstance(item, (list, tuple)):
                continue

            if len(item) >= 3:
                start, end, sentence = item[0], item[1], item[2]
            elif len(item) >= 2:
                start, end = item[0], item[1]
                sentence = text
            else:
                continue

            if not isinstance(sentence, str) or not sentence.strip():
                continue

            try:
                if float(end) <= float(start):
                    continue
            except Exception:
                continue

            subtitles.append((start, end, sentence.strip()))

        return subtitles

    return subtitles


def generate_srt(audio_path: str, srt_path: str) -> bool:
    try:
        model = AutoModel(
            model="paraformer-zh",
            vad_model="fsmn-vad",
            punc_model="ct-punc",
            device="cpu",
            disable_update=True
        )

        res = model.generate(
            input=audio_path,
            sentence_timestamp=True,
            hotword=""
        )

        subtitles = parse_asr_result(res)

        if not subtitles:
            print("no subtitle generated", file=sys.stderr)
            return False

        with open(srt_path, "w", encoding="utf-8") as f:
            for index, (start, end, text) in enumerate(subtitles, start=1):
                f.write(f"{index}\n")
                f.write(f"{format_timestamp(start)} --> {format_timestamp(end)}\n")
                f.write(f"{text}\n\n")

        return True

    except Exception as e:
        print(f"asr error: {type(e).__name__}: {e}", file=sys.stderr)
        return False


def overlay_subtitles(video_path: str, srt_path: str, output_path: str) -> bool:
    try:
        style = (
            "Fontsize=26,"
            "PrimaryColour=&H00FFFFFF,"
            "OutlineColour=&H00000000,"
            "BorderStyle=1,"
            "Outline=2,"
            "Shadow=0,"
            "MarginV=35"
        )

        safe_srt_path = srt_path.replace("\\", "\\\\").replace(":", "\\:")

        (
            ffmpeg
            .input(video_path)
            .output(
                output_path,
                vf=f"subtitles='{safe_srt_path}':force_style='{style}'",
                **{
                    "c:v": "libx264",
                    "crf": "20",
                    "preset": "medium",
                    "c:a": "copy",
                    "sn": None
                }
            )
            .run(overwrite_output=True, quiet=True)
        )

        return True

    except ffmpeg.Error as e:
        msg = e.stderr.decode("utf-8", errors="ignore") if e.stderr else str(e)
        print(f"ffmpeg overlay error: {msg}", file=sys.stderr)
        return False


def process_video(video_input: str, video_output: str) -> bool:
    if not os.path.isfile(video_input):
        print(f"input file not found: {video_input}", file=sys.stderr)
        return False

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_audio:
        audio_path = tmp_audio.name

    with tempfile.NamedTemporaryFile(suffix=".srt", delete=False) as tmp_srt:
        srt_path = tmp_srt.name

    try:
        if not extract_audio(video_input, audio_path):
            return False

        if not generate_srt(audio_path, srt_path):
            return False

        if not overlay_subtitles(video_input, srt_path, video_output):
            return False

        return True

    finally:
        for path in (audio_path, srt_path):
            if os.path.exists(path):
                os.unlink(path)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: python asr.py input.mp4 output.mp4", file=sys.stderr)
        return 1

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    ok = process_video(input_path, output_path)

    if ok:
        print(output_path)
        return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
