#include <stdio.h>
#include <libavcodec/avcodec.h>
#include <libavutil/hwcontext.h>
int main(void) {
 const AVCodec *c = avcodec_find_decoder_by_name("h264");
 const AVCodecHWConfig *h;
 int i;
 printf("decoder=%s\n", c ? c->name : "NULL");
 for (i=0; c && (h=avcodec_get_hw_config(c,i)); i++) printf("config %d fmt=%d dev=%d methods=%u\n",i,h->pix_fmt,h->device_type,h->methods);
 printf("D3D11 enum=%d first-device=%d\n", AV_HWDEVICE_TYPE_D3D11VA, av_hwdevice_iterate_types(AV_HWDEVICE_TYPE_NONE));
 return 0;
}
