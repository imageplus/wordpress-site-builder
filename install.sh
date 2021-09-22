checkInstalled(){
    if ! (hash "$1" 2>/dev/null); then
        echo "package $1 must be installed and available on path";
        
        return 1;
    else
#        echo "package $1 is installed";
        return 0;
    fi
}

#$1 is plugin name (inside base-plugins typically)
installPlugin(){
	cd "$1"

	if [ -f "composer.json" ]; then
		composer i -q --no-dev;
	fi

	rm -rf .git

	cd ..

	zip -q -r "$1.zip" "$1" 2>/dev/null

	rm -rf "$1"
}

#Check composer is installed
if ! (checkInstalled composer); then
    exit 1;
fi

#Check git is installed
if ! (checkInstalled git); then
    exit 1;
fi

#Check the wp command line object is installed
if ! (checkInstalled wp); then
	echo "installing wp-cli"
	echo ""

    composer global require wp-cli
fi

#Check the zip package is installed
if ! (checkInstalled zip); then
	echo "installing zip"
	echo ""

    sudo apt install zip
fi

echo "setting up git submodules"

git submodule init
git submodule update

echo "submodules initialized"

echo ""
echo "starting plugin setup"

cd "base-plugins"

echo "-- setting up image optimization"
installPlugin "imageplus-image-optimization"

echo "-- setting up site version control"
installPlugin "imageplus-site-version-control"

echo "-- setting up s3 uploads"
installPlugin "s3-uploads"

cd ..

echo "plugin setup complete"
echo ""

echo "installing wordpress"

#Install a new wordpress code
wp core download

#Create the wordpress config
wp config create --extra-php <<PHP
define( 'S3_UPLOADS_BUCKET', 'some-bucket/staging' ); //the bucket to use including environment
define( 'S3_UPLOADS_REGION', 'eu-west-2' ); //the s3 bucket region (excluding the rest of the URL)

define( 'S3_UPLOADS_KEY', 'YOUR_S3_KEY' ); //the access key for the user you wish to use for uploading to s3
define( 'S3_UPLOADS_SECRET', 'YOUR_S3_SECRET' ); //the secret you need to use for uploading to s3

define('SITE_VERSION_CONTROL_PASSWORD', 'password'); //add a custom password for site version control
PHP

#Create wp database
wp core install

#Install and activate required plugins

#wordpress-seo is Yoast SEO
#wp-mail-smtp as all sites should be using mailgun
#acf is local plugin as pro can't be installed directly from the wordpress plugin directory
wp plugin install "wordpress-seo" "wp-mail-smtp" "w3-total-cache" base-plugins/advanced-custom-fields-pro.zip base-plugins/imageplus-site-version-control.zip base-plugins/s3-uploads.zip base-plugins/imageplus-image-optimization.zip --quiet --activate

#remove hello dolly plugin
wp plugin delete "hello" "askimet" --quiet

#Install the base theme

#We have a folder for the theme not an archive so make the archive for Wordpress to handle
zip -q -r base-theme.zip base-theme 2>/dev/null

#Actually install and activate the theme
wp theme install base-theme.zip --activate

echo "wordpress install complete"
echo ""

echo "starting cleanup"

#Cleanup

#The theme is installed so we don't need the compressed one anymore so remove it
rm base-theme.zip
rm -rf base-theme

#We've installed all the plugins so we no longer need them
#rm -rf base-plugins

#rm -rf .git


#Copy the public gitignore to the theme as this should be stored in git
#cp public.gitignore public/wp-content/themes/base-theme/.gitignore

echo "cleanup complete"