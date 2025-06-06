#if __has_include(<zlib.h>)
#    import <zlib.h>
#endif

#import "NSData+Unzip.h"

NSData *_Nullable sentry_unzippedData(NSData *data)
{
    if (data.length == 0) {
        return data;
    }

    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.avail_in = (uint)data.length;
    stream.next_in = (Bytef *)data.bytes;
    stream.total_out = 0;
    stream.avail_out = 0;

    NSMutableData *decompressed = nil;
    // window bits set to use the largest sliding window and automatically detect the header
    if (inflateInit2(&stream, MAX_WBITS + 32) == Z_OK) {
        int err = Z_OK;
        decompressed = [NSMutableData dataWithCapacity:data.length * 2];
        while (err == Z_OK) {
            if (stream.total_out >= decompressed.length) {
                decompressed.length += data.length / 2;
            }
            stream.next_out = (uint8_t *)decompressed.mutableBytes + stream.total_out;
            stream.avail_out = (uInt)(decompressed.length - stream.total_out);
            err = inflate(&stream, Z_SYNC_FLUSH);
        }
        if (inflateEnd(&stream) == Z_OK) {
            if (err == Z_STREAM_END) {
                decompressed.length = stream.total_out;
            }
        }
    }

    return decompressed;
}
