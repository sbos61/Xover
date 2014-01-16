p 'hello from random'

# setup Random number

thres=[0.2,0.5,1.0]	# last element is always 1.0
lbl=['A','B','C']
selector=''

r = Random.rand
i=0
while(r>thres[i]) do
	count||=0
	p 'count is '+count.to_s

	i+=1
end
selector= lbl[i]




