fid = fopen('fftresult.bin','r');
dat = fread(fid, [2 inf], 'short');
size(dat)
fclose(fid);

fftln = 1024;
fq = (0:(fftln-1))/fftln;

plot(fq, dat(1,1:1024), fq, dat(2,1:1024));
