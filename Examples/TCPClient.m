
% Prepare connection
t = tcpip('localhost', 52002, 'NetworkRole', 'client')

% Open connection
fopen(t)

% Say hello
fwrite(t, num2str(now))

% Wait for bytes available
while t.BytesAvailable==0
   disp('Waiting for time') 
    
end

ti = fread(t,t.BytesAvailable);

ti = str2double(native2unicode(ti'))