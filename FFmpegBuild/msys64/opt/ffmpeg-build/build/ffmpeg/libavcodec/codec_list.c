static const FFCodec * const codec_list[] = {
    &ff_flac_encoder,
    &ff_pcm_s16le_encoder,
    &ff_libmp3lame_encoder,
    &ff_libopenh264_encoder,
    &ff_h264_mf_encoder,
    &ff_h264_nvenc_encoder,
    &ff_mp3_mf_encoder,
    &ff_h264_decoder,
    &ff_flac_decoder,
    &ff_mp3_decoder,
    &ff_pcm_s16le_decoder,
    NULL };
