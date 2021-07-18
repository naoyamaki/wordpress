data "aws_caller_identity" "self" { }
ecr_web_image = "${data.aws_caller_identity.self.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_web:latest"
ecr_app_image = "${data.aws_caller_identity.self.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_app:latest"
db_endpoint = "database-1.cluster-cf4o5tkwgral.ap-northeast-1.rds.amazonaws.com"
db_password = "x1X2x3X4x5X6x7X8x9X"