provider  "aws" {
   region  = "ap-south-1"
   profile = "newpradeep"
}

resource "tls_private_key" "my_key" {             
  algorithm = "RSA"
}

output "key" {
   value = tls_private_key.my_key
}


resource "local_file" "my_privatekey" {
    content     = tls_private_key.my_key.private_key_pem
    filename = "mykey112233"
    file_permission = 0400                             
}


resource "aws_key_pair" "my_key"{               
	key_name= "mykey123"
	public_key = tls_private_key.my_key.public_key_openssh
}

resource "aws_security_group" "mysecurity-httpd"{
     name = "mysecurity-httpd"
     description = "Web-server httpd port is allowed t connect"

      ingress{
             from_port = 80
             to_port = 80
             protocol = "tcp"
             cidr_blocks = ["0.0.0.0/0"]
     }
     ingress{
             from_port = 22
             to_port = 22
             protocol = "tcp"
             cidr_blocks = ["0.0.0.0/0"]
     }
     egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


resource "aws_instance"  "website" {
 depends_on = [ aws_security_group.mysecurity-httpd, aws_key_pair.my_key]
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  security_groups   = ["${aws_security_group.mysecurity-httpd.name}"] 
  key_name	= aws_key_pair.my_key.key_name
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.my_key.private_key_pem
    host     = aws_instance.website.public_ip
	
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "MyWebsite"
  }
}

resource "aws_ebs_volume" "esb2" {
  availability_zone = aws_instance.website.availability_zone
  size              = 1
  tags = {
    Name = "MyWebsiteebs"
  }
}

resource "aws_volume_attachment" "ebs_att" {
 depends_on = [
          aws_instance.website,
]
  device_name = "/dev/sdp"
  volume_id   = aws_ebs_volume.esb2.id
  instance_id = aws_instance.website.id
  force_detach = true
}

resource "null_resource" "mylocalnull1"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.website.public_ip} > publicip.txt"
  	}
}

resource "null_resource" "nullremote3"  {
  depends_on = [aws_volume_attachment.ebs_att, ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.my_key.private_key_pem
    host     = aws_instance.website.public_ip
  }


provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/KVSSKPRADEEP/multicloud.git /var/www/html/",
    ]
  }
}


resource "aws_s3_bucket" "pradeeps33bucket" {
  bucket = "pradeeps33bucket"
  
}
resource "aws_s3_bucket_object" "pradeeps33bucket" {
    depends_on = [aws_s3_bucket.pradeeps33bucket,]	
  	content_type="image/jpeg"             
  	bucket = "pradeeps33bucket"
  	key    = "31.jpg"           
  	source = "K:/31.jpg"
  	etag   = filemd5("K:/31.jpg")
  	acl    = "public-read"            
	}
locals {                
	s3_origin = "Mytask1S3"
}



# creating cloudfront 

resource "aws_cloudfront_distribution" "my_cd" {


   depends_on = [aws_s3_bucket.pradeeps33bucket]
   	origin {
   		domain_name = aws_s3_bucket.pradeeps33bucket.bucket_regional_domain_name
                                  origin_id   = local.s3_origin
  		}
  	enabled             = true


 	default_cache_behavior {
    		allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    		cached_methods   = ["GET", "HEAD"]
    		target_origin_id = local.s3_origin
    		forwarded_values {
      			query_string = false             
		      	cookies {
        			forward = "none"
     				}
    				}
    	viewer_protocol_policy = "allow-all"
    	min_ttl                = 0
    	default_ttl            = 3600
    	max_ttl                = 86400
  }
  	restrictions {
    	geo_restriction {
      	restriction_type = "none"
    }
  }
  	viewer_certificate {
    		cloudfront_default_certificate = true
  			}
}

# cloudfront URL into website 
resource "null_resource" "nullRemote4" {
   depends_on = [aws_cloudfront_distribution.my_cd, 
	aws_instance.website,
                 aws_key_pair.my_key,
]
	connection {
    	type   	  = "ssh"
    	user   	  = "ec2-user"
    	private_key   = tls_private_key.my_key.private_key_pem
    	host          = aws_instance.website.public_ip
    	}

provisioner "remote-exec" {
      inline = [ 
        # sudo su << \"EOF\" \n echo \"<img src='${aws_cloudfront_distribution.my_cd.domain_name}'>\" >> /var/www/html/index.html \n \"EOF\"
            "sudo su << EOF",
         "echo \"<img src='https://${aws_cloudfront_distribution.my_cd.domain_name}/${aws_s3_bucket_object.pradeeps33bucket.key}'>\" >> /var/www/html/index.html",
          "EOF"
     ]
  }
}

resource "null_resource" "link" {
     depends_on =[
          aws_instance.website,
]
  provisioner "local-exec" {
    command = "echo `http://${aws_instance.website.public_ip}/index.html` > Link_To_Webpage.txt"
  } 
}
